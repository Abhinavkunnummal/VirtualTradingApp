import { Socket } from 'socket.io';
import { config } from '../../config';
import { RealtimeMarketService } from './realtimeMarket.service';
import { AlphaVantageService } from './alphaVantage.service';
import { SocketService } from '../../services/socket.service';

export interface ChartCandle {
  time: number; // Unix timestamp in seconds (for Lightweight Charts)
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

export interface ChartTickPayload {
  symbol: string;
  interval: string;
  time: number; // Unix timestamp in seconds
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
  delayed?: boolean;
}

/**
 * Budget guard to prevent exhausting Alpha Vantage free tier limits (5 req/min, 100 req/day).
 */
export class RateLimitBudgetGuard {
  private maxPerMinute: number;
  private maxPerDay: number;
  private requestTimestamps: number[] = [];
  private dayCount: number = 0;
  private currentDay: string = '';

  constructor(maxPerMinute = 5, maxPerDay = 100) {
    this.maxPerMinute = maxPerMinute;
    this.maxPerDay = maxPerDay;
    this.currentDay = new Date().toISOString().slice(0, 10);
  }

  public setLimits(maxPerMinute: number, maxPerDay: number): void {
    this.maxPerMinute = maxPerMinute;
    this.maxPerDay = maxPerDay;
  }

  public canRequest(now = Date.now()): boolean {
    this.pruneOld(now);
    if (this.requestTimestamps.length >= this.maxPerMinute) {
      return false;
    }
    if (this.dayCount >= this.maxPerDay) {
      return false;
    }
    return true;
  }

  public recordRequest(now = Date.now()): boolean {
    if (!this.canRequest(now)) {
      return false;
    }
    this.requestTimestamps.push(now);
    this.dayCount++;
    return true;
  }

  public getStatus(now = Date.now()): {
    minuteUsed: number;
    maxPerMinute: number;
    dayUsed: number;
    maxPerDay: number;
    isBudgetExhausted: boolean;
  } {
    this.pruneOld(now);
    return {
      minuteUsed: this.requestTimestamps.length,
      maxPerMinute: this.maxPerMinute,
      dayUsed: this.dayCount,
      maxPerDay: this.maxPerDay,
      isBudgetExhausted: !this.canRequest(now),
    };
  }

  public reset(): void {
    this.requestTimestamps = [];
    this.dayCount = 0;
    this.currentDay = new Date().toISOString().slice(0, 10);
  }

  private pruneOld(now: number): void {
    const today = new Date(now).toISOString().slice(0, 10);
    if (today !== this.currentDay) {
      this.currentDay = today;
      this.dayCount = 0;
    }
    this.requestTimestamps = this.requestTimestamps.filter((t) => now - t < 60000);
  }
}

/**
 * Returns candle duration in seconds.
 */
export function getIntervalSeconds(interval: string): number {
  switch (interval.toLowerCase()) {
    case '1m':
      return 60;
    case '5m':
      return 300;
    case '15m':
      return 900;
    case '1h':
      return 3600;
    case '1d':
      return 86400;
    default:
      return 900;
  }
}

/**
 * Computes interval bucket start timestamp in unix seconds.
 */
export function getIntervalStartTime(timestampSec: number, interval: string): number {
  const normInterval = interval.toLowerCase();
  if (normInterval === '1d') {
    const d = new Date(timestampSec * 1000);
    return Math.floor(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()) / 1000);
  }
  const sec = getIntervalSeconds(normInterval);
  return Math.floor(timestampSec / sec) * sec;
}

export interface CandleAggregationResult {
  candle: ChartCandle;
  isNewCandle: boolean;
}

/**
 * Aggregates a price tick into the forming candle.
 * Returns the forming candle and whether a new interval rollover occurred.
 */
export function aggregateCandleTick(
  currentCandle: ChartCandle | null | undefined,
  price: number,
  volume = 0,
  timestampSec = Math.floor(Date.now() / 1000),
  interval = '15m'
): CandleAggregationResult {
  const intervalStartTime = getIntervalStartTime(timestampSec, interval);

  if (!currentCandle || intervalStartTime > currentCandle.time) {
    const isNew = currentCandle !== null && currentCandle !== undefined;
    return {
      candle: {
        time: intervalStartTime,
        open: price,
        high: price,
        low: price,
        close: price,
        volume: volume || 0,
      },
      isNewCandle: isNew,
    };
  }

  return {
    candle: {
      time: currentCandle.time,
      open: currentCandle.open,
      high: Math.max(currentCandle.high, price),
      low: Math.min(currentCandle.low, price),
      close: price,
      volume: currentCandle.volume + (volume || 0),
    },
    isNewCandle: false,
  };
}

/**
 * Maps user symbol to Binance format (e.g. BTC/USDT -> btcusdt).
 */
export function toBinanceSymbol(symbol: string): string {
  let s = symbol.toUpperCase().replace('/', '').replace('-', '').trim();
  if (!s.endsWith('USDT') && !s.endsWith('USD') && !s.endsWith('BUSD')) {
    s = `${s}USDT`;
  }
  return s.toLowerCase();
}

/**
 * Formats stream name for Binance Kline stream.
 */
export function toBinanceStream(symbol: string, interval: string): string {
  return `${toBinanceSymbol(symbol)}@kline_${interval.toLowerCase()}`;
}

export interface RoomSubscription {
  symbol: string;
  interval: string;
  roomName: string;
}

/**
 * Real-time Chart Streaming Service:
 * - Bridges Binance WebSocket for 24/7 tick-for-tick crypto klines
 * - Shared rate-limited poller for non-crypto symbols (Alpha Vantage guard)
 * - Candle aggregation and interval rollover
 * - Automatic subscription and connection cleanup when rooms are empty
 */
export class ChartStreamService {
  private static binanceWs: WebSocket | null = null;
  private static activeWsUrl: string = config.binanceWsUrl;
  private static reconnectTimer: NodeJS.Timeout | null = null;
  private static reconnectDelay = 1000;
  private static isConnectingWs = false;

  // Active Binance streams -> set of RoomSubscriptions
  private static binanceStreamToRooms = new Map<string, Map<string, RoomSubscription>>();

  // Active non-crypto symbols -> set of intervals
  private static activeNonCrypto = new Map<string, Set<string>>();
  private static nonCryptoPollTimer: NodeJS.Timeout | null = null;
  private static isPollingNonCrypto = false;

  // Room tracking: roomName -> Set of socket IDs
  private static roomSubscribers = new Map<string, Set<string>>();

  // Socket tracking: socket ID -> Set of roomNames
  private static socketSubscriptions = new Map<string, Set<string>>();

  // Current forming candle per room: roomName -> ChartCandle
  private static formingCandles = new Map<string, ChartCandle>();

  // Rate limit guard for non-crypto upstream
  private static budgetGuard = new RateLimitBudgetGuard(5, 100);

  public static getBudgetGuard(): RateLimitBudgetGuard {
    return this.budgetGuard;
  }

  public static getFormingCandle(symbol: string, interval = '15m'): ChartCandle | undefined {
    const roomName = `chart:${symbol.toUpperCase()}:${interval.toLowerCase()}`;
    return this.formingCandles.get(roomName);
  }

  public static getSubscriberCount(roomName: string): number {
    return this.roomSubscribers.get(roomName)?.size || 0;
  }

  /**
   * Handle socket client subscription to "chart:subscribe"
   */
  public static handleSubscribe(
    socket: Socket,
    data: { symbol: string; interval?: string }
  ): void {
    if (!data?.symbol || typeof data.symbol !== 'string') return;

    const symbol = data.symbol.toUpperCase().trim();
    const interval = (data.interval || '15m').toLowerCase();
    const roomName = `chart:${symbol}:${interval}`;

    // Join Socket.IO room
    socket.join(roomName);

    // Track for this socket
    if (!this.socketSubscriptions.has(socket.id)) {
      this.socketSubscriptions.set(socket.id, new Set());
    }
    this.socketSubscriptions.get(socket.id)!.add(roomName);

    // Track for room
    if (!this.roomSubscribers.has(roomName)) {
      this.roomSubscribers.set(roomName, new Set());
    }
    const subscribers = this.roomSubscribers.get(roomName)!;
    const isFirstSubscriber = subscribers.size === 0;
    subscribers.add(socket.id);

    // Emit existing forming candle immediately if cached
    const existing = this.formingCandles.get(roomName);
    if (existing) {
      const payload: ChartTickPayload = {
        symbol,
        interval,
        time: existing.time,
        open: existing.open,
        high: existing.high,
        low: existing.low,
        close: existing.close,
        volume: existing.volume,
        delayed: false,
      };
      socket.emit('chart:tick', payload);
    }

    // Register upstream stream if first subscriber
    if (isFirstSubscriber) {
      const isCrypto = this.isCryptoSymbol(symbol);
      if (isCrypto) {
        this.registerCryptoStream(symbol, interval, roomName);
      } else {
        this.registerNonCryptoStream(symbol, interval);
      }
    }
  }

  /**
   * Handle socket client unsubscription from "chart:unsubscribe"
   */
  public static handleUnsubscribe(
    socket: Socket,
    data?: { symbol?: string; interval?: string }
  ): void {
    const socketRooms = this.socketSubscriptions.get(socket.id);
    if (!socketRooms || socketRooms.size === 0) return;

    const targetSymbol = data?.symbol ? data.symbol.toUpperCase().trim() : null;
    const targetInterval = data?.interval ? data.interval.toLowerCase() : null;

    const roomsToLeave: string[] = [];
    for (const roomName of socketRooms) {
      const [, roomSymbol, roomInterval] = roomName.split(':');
      if (
        (!targetSymbol || targetSymbol === roomSymbol) &&
        (!targetInterval || targetInterval === roomInterval)
      ) {
        roomsToLeave.push(roomName);
      }
    }

    for (const roomName of roomsToLeave) {
      socket.leave(roomName);
      socketRooms.delete(roomName);

      const subscribers = this.roomSubscribers.get(roomName);
      if (subscribers) {
        subscribers.delete(socket.id);
        if (subscribers.size === 0) {
          this.roomSubscribers.delete(roomName);
          this.cleanupEmptyRoom(roomName);
        }
      }
    }

    if (socketRooms.size === 0) {
      this.socketSubscriptions.delete(socket.id);
    }
  }

  /**
   * Handle socket disconnection
   */
  public static handleDisconnect(socket: Socket): void {
    this.handleUnsubscribe(socket);
    this.socketSubscriptions.delete(socket.id);
  }

  private static isCryptoSymbol(symbol: string): boolean {
    const mapping = RealtimeMarketService.getMapping(symbol);
    return mapping.category === 'CRYPTO';
  }

  // --- Crypto Stream Management (Binance WebSocket) ---

  private static registerCryptoStream(symbol: string, interval: string, roomName: string): void {
    const streamName = toBinanceStream(symbol, interval);

    if (!this.binanceStreamToRooms.has(streamName)) {
      this.binanceStreamToRooms.set(streamName, new Map());
    }
    this.binanceStreamToRooms.get(streamName)!.set(roomName, { symbol, interval, roomName });

    // Send SUBSCRIBE frame if WS is connected
    if (this.binanceWs && this.binanceWs.readyState === WebSocket.OPEN) {
      this.binanceWs.send(
        JSON.stringify({
          method: 'SUBSCRIBE',
          params: [streamName],
          id: Date.now(),
        })
      );
    } else {
      this.ensureBinanceWsConnected();
    }
  }

  private static unregisterCryptoStream(symbol: string, interval: string, roomName: string): void {
    const streamName = toBinanceStream(symbol, interval);
    const rooms = this.binanceStreamToRooms.get(streamName);
    if (!rooms) return;

    rooms.delete(roomName);
    if (rooms.size === 0) {
      this.binanceStreamToRooms.delete(streamName);

      if (this.binanceWs && this.binanceWs.readyState === WebSocket.OPEN) {
        this.binanceWs.send(
          JSON.stringify({
            method: 'UNSUBSCRIBE',
            params: [streamName],
            id: Date.now(),
          })
        );
      }

      // If no crypto rooms remain, close the WS connection completely
      if (this.binanceStreamToRooms.size === 0) {
        this.closeBinanceWs();
      }
    }
  }

  private static ensureBinanceWsConnected(): void {
    if (process.env.NODE_ENV === 'test') {
      // In test mode, do not establish real network connection unless configured
      return;
    }

    if (this.binanceWs || this.isConnectingWs) return;
    if (this.binanceStreamToRooms.size === 0) return;

    this.isConnectingWs = true;
    try {
      const ws = new WebSocket(this.activeWsUrl);
      this.binanceWs = ws;

      ws.onopen = () => {
        this.isConnectingWs = false;
        this.reconnectDelay = 1000;
        const streams = Array.from(this.binanceStreamToRooms.keys());
        if (streams.length > 0) {
          ws.send(
            JSON.stringify({
              method: 'SUBSCRIBE',
              params: streams,
              id: Date.now(),
            })
          );
        }
      };

      ws.onmessage = (event: MessageEvent) => {
        try {
          const raw = typeof event.data === 'string' ? event.data : event.data?.toString();
          if (!raw) return;
          const parsed = JSON.parse(raw);
          this.processBinanceMessage(parsed);
        } catch {
          // ignore parse errors
        }
      };

      ws.onerror = () => {
        // Fallback if primary fails
        if (this.activeWsUrl === config.binanceWsUrl && config.binanceWsFallbackUrl) {
          this.activeWsUrl = config.binanceWsFallbackUrl;
        }
      };

      ws.onclose = () => {
        this.binanceWs = null;
        this.isConnectingWs = false;
        if (this.binanceStreamToRooms.size > 0) {
          this.scheduleBinanceReconnect();
        }
      };
    } catch {
      this.binanceWs = null;
      this.isConnectingWs = false;
      this.scheduleBinanceReconnect();
    }
  }

  private static scheduleBinanceReconnect(): void {
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    if (this.binanceStreamToRooms.size === 0) return;

    const delay = Math.min(this.reconnectDelay, 30000);
    this.reconnectDelay = Math.min(this.reconnectDelay * 2, 30000);

    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.ensureBinanceWsConnected();
    }, delay);
  }

  private static closeBinanceWs(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    if (this.binanceWs) {
      try {
        this.binanceWs.close();
      } catch {
        // ignore
      }
      this.binanceWs = null;
    }
    this.isConnectingWs = false;
  }

  /**
   * Process incoming Binance Kline event and broadcast to subscribed rooms
   */
  public static processBinanceMessage(data: any): void {
    if (!data || data.e !== 'kline' || !data.k) return;

    const k = data.k;
    const streamName = `${String(data.s).toLowerCase()}@kline_${String(k.i).toLowerCase()}`;
    const rooms = this.binanceStreamToRooms.get(streamName);
    if (!rooms || rooms.size === 0) return;

    const time = Math.floor(k.t / 1000);
    const open = parseFloat(k.o);
    const high = parseFloat(k.h);
    const low = parseFloat(k.l);
    const close = parseFloat(k.c);
    const volume = parseFloat(k.v);

    for (const sub of rooms.values()) {
      const candle: ChartCandle = { time, open, high, low, close, volume };
      this.formingCandles.set(sub.roomName, candle);

      const payload: ChartTickPayload = {
        symbol: sub.symbol,
        interval: sub.interval,
        time,
        open,
        high,
        low,
        close,
        volume,
        delayed: false,
      };

      SocketService.getIO()?.to(sub.roomName).emit('chart:tick', payload);
    }
  }

  // --- Non-Crypto Stream Management (Alpha Vantage Rate Guarded Polling) ---

  private static registerNonCryptoStream(symbol: string, interval: string): void {
    if (!this.activeNonCrypto.has(symbol)) {
      this.activeNonCrypto.set(symbol, new Set());
    }
    this.activeNonCrypto.get(symbol)!.add(interval);

    // Initial fetch for the symbol
    this.pollSingleNonCrypto(symbol);

    // Start shared poll loop if not running
    if (!this.nonCryptoPollTimer && process.env.NODE_ENV !== 'test') {
      this.nonCryptoPollTimer = setInterval(() => {
        this.pollActiveNonCrypto();
      }, 15000);
    }
  }

  private static unregisterNonCryptoStream(symbol: string, interval: string): void {
    const intervals = this.activeNonCrypto.get(symbol);
    if (!intervals) return;

    intervals.delete(interval);
    if (intervals.size === 0) {
      this.activeNonCrypto.delete(symbol);
    }

    if (this.activeNonCrypto.size === 0 && this.nonCryptoPollTimer) {
      clearInterval(this.nonCryptoPollTimer);
      this.nonCryptoPollTimer = null;
    }
  }

  /**
   * Poll a single non-crypto symbol and emit tick to its interval rooms
   */
  public static async pollSingleNonCrypto(symbol: string): Promise<void> {
    const intervals = this.activeNonCrypto.get(symbol);
    if (!intervals || intervals.size === 0) return;

    const canRequest = this.budgetGuard.canRequest();
    let price: number | null = null;
    let volume = 0;
    let isDelayed = false;

    if (canRequest) {
      try {
        let liveQuote = null;
        if (AlphaVantageService.isConfigured()) {
          liveQuote = await AlphaVantageService.fetchGlobalQuote(symbol);
        }
        if (!liveQuote) {
          liveQuote = await RealtimeMarketService.getLiveQuote(symbol);
        }

        if (liveQuote && typeof liveQuote.price === 'number') {
          price = liveQuote.price;
          volume = liveQuote.volume || 1000;
          this.budgetGuard.recordRequest();
        }
      } catch {
        // Fall back to cached candle
      }
    }

    // If budget exhausted or fetch failed, fallback to cached candle close
    if (price === null) {
      isDelayed = true;
      for (const interval of intervals) {
        const roomName = `chart:${symbol}:${interval}`;
        const cached = this.formingCandles.get(roomName);
        if (cached) {
          price = cached.close;
          break;
        }
      }
    }

    if (price === null) return;

    const nowSec = Math.floor(Date.now() / 1000);
    for (const interval of intervals) {
      const roomName = `chart:${symbol}:${interval}`;
      const currentCandle = this.formingCandles.get(roomName);
      const agg = aggregateCandleTick(currentCandle, price, volume, nowSec, interval);

      this.formingCandles.set(roomName, agg.candle);

      const payload: ChartTickPayload = {
        symbol,
        interval,
        time: agg.candle.time,
        open: agg.candle.open,
        high: agg.candle.high,
        low: agg.candle.low,
        close: agg.candle.close,
        volume: agg.candle.volume,
        delayed: isDelayed,
      };

      SocketService.getIO()?.to(roomName).emit('chart:tick', payload);
    }
  }

  private static async pollActiveNonCrypto(): Promise<void> {
    if (this.isPollingNonCrypto) return;
    this.isPollingNonCrypto = true;
    try {
      const symbols = Array.from(this.activeNonCrypto.keys());
      for (const symbol of symbols) {
        await this.pollSingleNonCrypto(symbol);
      }
    } finally {
      this.isPollingNonCrypto = false;
    }
  }

  // --- Cleanup ---

  private static cleanupEmptyRoom(roomName: string): void {
    const [, symbol, interval] = roomName.split(':');
    if (!symbol || !interval) return;

    const isCrypto = this.isCryptoSymbol(symbol);
    if (isCrypto) {
      this.unregisterCryptoStream(symbol, interval, roomName);
    } else {
      this.unregisterNonCryptoStream(symbol, interval);
    }
  }

  /**
   * Reset all internal states (useful for Jest tests)
   */
  public static resetForTesting(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    if (this.nonCryptoPollTimer) {
      clearInterval(this.nonCryptoPollTimer);
      this.nonCryptoPollTimer = null;
    }
    if (this.binanceWs) {
      try {
        this.binanceWs.close();
      } catch {
        // ignore
      }
      this.binanceWs = null;
    }
    this.isConnectingWs = false;
    this.reconnectDelay = 1000;
    this.activeWsUrl = config.binanceWsUrl;
    this.binanceStreamToRooms.clear();
    this.activeNonCrypto.clear();
    this.roomSubscribers.clear();
    this.socketSubscriptions.clear();
    this.formingCandles.clear();
    this.budgetGuard.reset();
  }
}
