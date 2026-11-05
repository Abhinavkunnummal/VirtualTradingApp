import crypto from 'crypto';
import { config } from '../../config';

export interface AngelOneQuoteTick {
  token: string;
  symbol: string;
  exchange: 'NSE' | 'BSE' | 'MCX';
  price: number;
  volume: number;
  timestamp: number; // Unix seconds
}

export interface AngelOneHistoricalCandle {
  timestamp: number;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

export type AngelOneTickListener = (tick: AngelOneQuoteTick) => void;

/**
 * Generate standard RFC 6238 TOTP using Node.js built-in crypto
 */
export function generateTOTP(secretBase32: string, step = 30): string {
  if (!secretBase32) return '';
  const clean = secretBase32.replace(/[\s=-]/g, '').toUpperCase();
  const base32chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (let i = 0; i < clean.length; i++) {
    const val = base32chars.indexOf(clean.charAt(i));
    if (val >= 0) bits += val.toString(2).padStart(5, '0');
  }
  const keyBytes: number[] = [];
  for (let i = 0; i + 8 <= bits.length; i += 8) {
    keyBytes.push(parseInt(bits.substr(i, 8), 2));
  }
  const epoch = Math.floor(Date.now() / 1000);
  const timeStep = Math.floor(epoch / step);
  const timeBuf = Buffer.alloc(8);
  timeBuf.writeBigInt64BE(BigInt(timeStep));

  const hmac = crypto.createHmac('sha1', Buffer.from(keyBytes));
  hmac.update(timeBuf);
  const digest = hmac.digest();

  const offset = digest[digest.length - 1] & 0xf;
  const code =
    ((digest[offset] & 0x7f) << 24) |
    ((digest[offset + 1] & 0xff) << 16) |
    ((digest[offset + 2] & 0xff) << 8) |
    (digest[offset + 3] & 0xff);
  return (code % 1000000).toString().padStart(6, '0');
}

/**
 * Static token map for popular instruments across NSE, BSE, MCX
 */
const KNOWN_TOKENS: Record<string, { token: string; exchange: 'NSE' | 'BSE' | 'MCX'; exchType: number }> = {
  // NSE Equities (exchType 1)
  'RELIANCE': { token: '2885', exchange: 'NSE', exchType: 1 },
  'TCS': { token: '11536', exchange: 'NSE', exchType: 1 },
  'INFY': { token: '1594', exchange: 'NSE', exchType: 1 },
  'HDFCBANK': { token: '1333', exchange: 'NSE', exchType: 1 },
  'ICICIBANK': { token: '4963', exchange: 'NSE', exchType: 1 },
  'SBIN': { token: '3045', exchange: 'NSE', exchType: 1 },
  'BHARTIARTL': { token: '10604', exchange: 'NSE', exchType: 1 },
  'ITC': { token: '1660', exchange: 'NSE', exchType: 1 },
  'KOTAKBANK': { token: '1922', exchange: 'NSE', exchType: 1 },
  'LT': { token: '11483', exchange: 'NSE', exchType: 1 },
  'TATAMOTORS': { token: '3456', exchange: 'NSE', exchType: 1 },
  'BAJFINANCE': { token: '317', exchange: 'NSE', exchType: 1 },
  'MARUTI': { token: '10999', exchange: 'NSE', exchType: 1 },
  'SUNPHARMA': { token: '3351', exchange: 'NSE', exchType: 1 },
  'TITAN': { token: '3506', exchange: 'NSE', exchType: 1 },
  'WIPRO': { token: '3787', exchange: 'NSE', exchType: 1 },
  'TATASTEEL': { token: '3499', exchange: 'NSE', exchType: 1 },
  'AXISBANK': { token: '5900', exchange: 'NSE', exchType: 1 },
  'YESBANK': { token: '11915', exchange: 'NSE', exchType: 1 },
  'IDEA': { token: '14366', exchange: 'NSE', exchType: 1 },
  'KNRCON': { token: '14574', exchange: 'NSE', exchType: 1 },
  'JIOFIN': { token: '18143', exchange: 'NSE', exchType: 1 },
  'ADANIENT': { token: '25', exchange: 'NSE', exchType: 1 },
  'ADANIPORTS': { token: '15083', exchange: 'NSE', exchType: 1 },

  // NSE Indices
  'NIFTY 50': { token: '26000', exchange: 'NSE', exchType: 1 },
  'NIFTY': { token: '26000', exchange: 'NSE', exchType: 1 },
  'BANKNIFTY': { token: '26009', exchange: 'NSE', exchType: 1 },
  'FINNIFTY': { token: '26037', exchange: 'NSE', exchType: 1 },

  // BSE Equities & Indices (exchType 3)
  'SENSEX': { token: '1', exchange: 'BSE', exchType: 3 },
  '500325': { token: '500325', exchange: 'BSE', exchType: 3 }, // RELIANCE on BSE
  '500180': { token: '500180', exchange: 'BSE', exchType: 3 }, // HDFCBANK on BSE
  '500112': { token: '500112', exchange: 'BSE', exchType: 3 }, // SBIN on BSE
  '532648': { token: '532648', exchange: 'BSE', exchType: 3 }, // YESBANK on BSE
  '532822': { token: '532822', exchange: 'BSE', exchType: 3 }, // IDEA on BSE
  '543940': { token: '543940', exchange: 'BSE', exchType: 3 }, // JIOFIN on BSE
  '532942': { token: '532942', exchange: 'BSE', exchType: 3 }, // KNRCON on BSE

  // MCX Commodities (exchType 5)
  'GOLD': { token: '248740', exchange: 'MCX', exchType: 5 },
  'GOLD 1KG': { token: '248740', exchange: 'MCX', exchType: 5 },
  'SILVER': { token: '248890', exchange: 'MCX', exchType: 5 },
  'SILVER 30KG': { token: '248890', exchange: 'MCX', exchType: 5 },
  'CRUDEOIL': { token: '249580', exchange: 'MCX', exchType: 5 },
  'NATURALGAS': { token: '249300', exchange: 'MCX', exchType: 5 },
};

export class AngelOneService {
  private static jwtToken: string | null = null;
  private static refreshToken: string | null = null;
  private static feedToken: string | null = null;
  private static tokenExpiresAt: number = 0;
  private static isLoggingIn: boolean = false;

  private static ws: WebSocket | null = null;
  private static isConnectingWs: boolean = false;
  private static reconnectTimer: NodeJS.Timeout | null = null;
  private static reconnectDelay: number = 1000;
  private static pingInterval: NodeJS.Timeout | null = null;

  // Viewers tracking: token -> Set of room/symbol keys
  private static subscribedTokens = new Map<string, Set<string>>();
  private static tokenToSymbol = new Map<string, { symbol: string; exchange: 'NSE' | 'BSE' | 'MCX' }>();
  private static symbolToToken = new Map<string, { token: string; exchange: 'NSE' | 'BSE' | 'MCX'; exchType: number }>();

  private static listeners: Set<AngelOneTickListener> = new Set();
  private static masterScripLoaded: boolean = false;

  public static readonly SUBSCRIPTION_CAP = 500;

  static {
    // Populate known tokens into fast lookups
    for (const [sym, info] of Object.entries(KNOWN_TOKENS)) {
      this.symbolToToken.set(sym.toUpperCase(), info);
      this.tokenToSymbol.set(info.token, { symbol: sym.toUpperCase(), exchange: info.exchange });
    }
  }

  public static isConfigured(): boolean {
    return Boolean(
      config.angelOneApiKey &&
      config.angelOneClientCode &&
      config.angelOnePin &&
      config.angelOneTotpSecret
    );
  }

  public static isConnected(): boolean {
    return Boolean(this.ws && this.ws.readyState === WebSocket.OPEN && this.jwtToken);
  }

  public static async init(): Promise<boolean> {
    if (!this.isConfigured()) return false;
    const ok = await this.login();
    if (ok) {
      await this.connectWebSocket();
    }
    return ok;
  }

  public static addTickListener(listener: AngelOneTickListener): void {
    this.listeners.add(listener);
  }

  public static removeTickListener(listener: AngelOneTickListener): void {
    this.listeners.delete(listener);
  }

  /**
   * Login using SmartAPI partner auth with TOTP
   */
  public static async login(): Promise<boolean> {
    if (!this.isConfigured()) return false;
    if (this.isLoggingIn) return false;

    this.isLoggingIn = true;
    try {
      const totp = generateTOTP(config.angelOneTotpSecret);
      const url = 'https://apiconnect.angelone.in/rest/auth/angelbroking/user/v1/loginByPassword';

      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-UserType': 'USER',
          'X-SourceID': 'WEB',
          'X-ClientLocalIP': '127.0.0.1',
          'X-ClientPublicIP': '127.0.0.1',
          'X-MACAddress': '00:00:00:00:00:00',
          'X-PrivateKey': config.angelOneApiKey,
        },
        body: JSON.stringify({
          clientcode: config.angelOneClientCode,
          password: config.angelOnePin,
          totp,
        }),
        signal: AbortSignal.timeout(10000),
      });

      const text = await res.text();
      let json: any = null;
      try {
        json = JSON.parse(text);
      } catch {
        console.warn(`[AngelOne] Auth HTTP ${res.status}: non-JSON response (${text.slice(0, 120)})`);
      }

      if (res.ok && json) {
        if (json?.status && json?.data?.jwtToken) {
          this.jwtToken = json.data.jwtToken.startsWith('Bearer ')
            ? json.data.jwtToken
            : `Bearer ${json.data.jwtToken}`;
          this.refreshToken = json.data.refreshToken;
          this.feedToken = json.data.feedToken;
          // Tokens valid for ~24h; refresh after 20h
          this.tokenExpiresAt = Date.now() + 20 * 60 * 60 * 1000;
          console.log('[AngelOne] Successfully authenticated SmartAPI session.');
          return true;
        } else {
          console.warn('[AngelOne] Authentication rejected:', json?.message || json?.errorcode || 'Invalid credentials');
        }
      } else if (!res.ok) {
        console.warn(`[AngelOne] Auth failed HTTP ${res.status}: ${json?.message || text.slice(0, 120)}`);
      }
    } catch (e) {
      console.warn('[AngelOne] Authentication request failed:', (e as Error).message);
    } finally {
      this.isLoggingIn = false;
    }
    return false;
  }

  public static async ensureLoggedIn(): Promise<boolean> {
    if (!this.isConfigured()) return false;
    if (this.jwtToken && Date.now() < this.tokenExpiresAt) {
      return true;
    }
    return await this.login();
  }

  /**
   * Resolve an instrument to Angel One symbolToken & exchange
   */
  public static resolveToken(rawSymbol: string): { token: string; exchange: 'NSE' | 'BSE' | 'MCX'; exchType: number } | null {
    const clean = rawSymbol.toUpperCase().replace(/\.(NS|BO)$/, '').trim();
    const mapped = this.symbolToToken.get(clean);
    if (mapped) return mapped;

    if (clean.includes('NIFTY')) {
      return { token: '26000', exchange: 'NSE', exchType: 1 };
    }
    if (clean.includes('BANKNIFTY')) {
      return { token: '26009', exchange: 'NSE', exchType: 1 };
    }
    if (clean.includes('SENSEX')) {
      return { token: '1', exchange: 'BSE', exchType: 3 };
    }

    return null;
  }

  /**
   * Connect to SmartAPI SmartWebSocketV2
   */
  public static async connectWebSocket(): Promise<void> {
    if (!this.isConfigured()) return;
    if (this.ws && (this.ws.readyState === WebSocket.OPEN || this.ws.readyState === WebSocket.CONNECTING)) {
      return;
    }

    const authed = await this.ensureLoggedIn();
    if (!authed || !this.jwtToken) return;

    this.isConnectingWs = true;
    try {
      const cleanJwt = this.jwtToken.replace(/^Bearer\s+/i, '');
      const wsUrl = `wss://smartapisocket.angelone.in/smart-stream?clientCode=${encodeURIComponent(config.angelOneClientCode)}&feedToken=${encodeURIComponent(this.feedToken || '')}&apiKey=${encodeURIComponent(config.angelOneApiKey)}`;

      const ws = new WebSocket(wsUrl, {
        headers: {
          'Authorization': this.jwtToken,
          'x-api-key': config.angelOneApiKey,
          'x-client-code': config.angelOneClientCode,
          'x-feed-token': this.feedToken || '',
        },
      } as any);

      this.ws = ws;

      ws.onopen = () => {
        this.isConnectingWs = false;
        this.reconnectDelay = 1000;
        console.log('[AngelOne] SmartStream V2 WebSocket connected.');

        // Re-subscribe any existing active viewers
        this.resubscribeActiveTokens();

        // 30s heartbeat ping
        if (this.pingInterval) clearInterval(this.pingInterval);
        this.pingInterval = setInterval(() => {
          if (ws.readyState === WebSocket.OPEN) {
            try {
              ws.send('ping');
            } catch {}
          }
        }, 30000);
      };

      ws.onmessage = (event: MessageEvent) => {
        this.handleMessage(event.data);
      };

      ws.onerror = (err: any) => {
        console.warn('[AngelOne] SmartStream WebSocket error:', err?.message || 'Connection error');
      };

      ws.onclose = () => {
        this.ws = null;
        this.isConnectingWs = false;
        if (this.pingInterval) {
          clearInterval(this.pingInterval);
          this.pingInterval = null;
        }
        if (this.subscribedTokens.size > 0) {
          this.scheduleReconnect();
        }
      };
    } catch (e) {
      this.ws = null;
      this.isConnectingWs = false;
      this.scheduleReconnect();
    }
  }

  private static scheduleReconnect(): void {
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    const delay = Math.min(this.reconnectDelay, 30000);
    this.reconnectDelay = Math.min(this.reconnectDelay * 2, 30000);

    this.reconnectTimer = setTimeout(async () => {
      this.reconnectTimer = null;
      await this.ensureLoggedIn();
      this.connectWebSocket();
    }, delay);
  }

  /**
   * Subscribe an active instrument room to live tick feed
   */
  public static subscribe(symbol: string, roomKey: string): void {
    const tokenInfo = this.resolveToken(symbol);
    if (!tokenInfo) return;

    if (!this.subscribedTokens.has(tokenInfo.token)) {
      if (this.subscribedTokens.size >= this.SUBSCRIPTION_CAP) {
        console.warn(`[AngelOne] Subscription cap (${this.SUBSCRIPTION_CAP}) reached. Dropping subscription for ${symbol}`);
        return;
      }
      this.subscribedTokens.set(tokenInfo.token, new Set());
    }

    const viewers = this.subscribedTokens.get(tokenInfo.token)!;
    const isFirstViewer = viewers.size === 0;
    viewers.add(roomKey);

    if (isFirstViewer) {
      this.sendSubscriptionFrame([tokenInfo], 1); // 1 = Subscribe
      if (!this.isConnected()) {
        this.connectWebSocket();
      }
    }
  }

  /**
   * Unsubscribe when viewer leaves
   */
  public static unsubscribe(symbol: string, roomKey: string): void {
    const tokenInfo = this.resolveToken(symbol);
    if (!tokenInfo) return;

    const viewers = this.subscribedTokens.get(tokenInfo.token);
    if (!viewers) return;

    viewers.delete(roomKey);
    if (viewers.size === 0) {
      this.subscribedTokens.delete(tokenInfo.token);
      this.sendSubscriptionFrame([tokenInfo], 0); // 0 = Unsubscribe

      // If no tokens subscribed, gracefully close socket
      if (this.subscribedTokens.size === 0 && this.ws) {
        try {
          this.ws.close();
        } catch {}
        this.ws = null;
      }
    }
  }

  private static sendSubscriptionFrame(tokens: Array<{ token: string; exchType: number }>, action: 1 | 0): void {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return;

    // Group by exchangeType
    const grouped = new Map<number, string[]>();
    for (const t of tokens) {
      if (!grouped.has(t.exchType)) grouped.set(t.exchType, []);
      grouped.get(t.exchType)!.push(t.token);
    }

    const tokenList = Array.from(grouped.entries()).map(([exchangeType, tokenArr]) => ({
      exchangeType,
      tokens: tokenArr,
    }));

    const frame = {
      correlationID: `stream_${Date.now().toString().slice(-6)}`,
      action, // 1 = Subscribe, 0 = Unsubscribe
      params: {
        mode: 1, // 1 = Quote Mode (LTP, Vol, Ts)
        tokenList,
      },
    };

    try {
      this.ws.send(JSON.stringify(frame));
    } catch {}
  }

  private static resubscribeActiveTokens(): void {
    const tokens: Array<{ token: string; exchType: number }> = [];
    for (const token of this.subscribedTokens.keys()) {
      const info = this.tokenToSymbol.get(token);
      const exchType = info?.exchange === 'BSE' ? 3 : info?.exchange === 'MCX' ? 5 : 1;
      tokens.push({ token, exchType });
    }
    if (tokens.length > 0) {
      this.sendSubscriptionFrame(tokens, 1);
    }
  }

  /**
   * Parse SmartStream V2 binary frame (83 bytes Quote packet)
   */
  private static handleMessage(data: any): void {
    try {
      if (typeof data === 'string') {
        if (data === 'pong') return;
        const parsed = JSON.parse(data);
        if (parsed?.data?.token && parsed?.data?.last_traded_price) {
          this.emitTick(
            parsed.data.token,
            parseFloat(parsed.data.last_traded_price) / 100,
            parseInt(parsed.data.volume || '0', 10),
            Math.floor(Date.now() / 1000)
          );
        }
        return;
      }

      const buffer: Buffer = Buffer.isBuffer(data) ? data : Buffer.from(data);
      if (buffer.length < 51) return; // Minimum Quote packet

      const mode = buffer.readUInt8(0);
      const exchType = buffer.readUInt8(1);

      // Token is 25 bytes null-padded string
      const tokenStr = buffer.toString('utf8', 2, 27).replace(/\0/g, '').trim();

      // Exchange Timestamp (8 bytes int64)
      let exchangeTs = Math.floor(Date.now() / 1000);
      try {
        const tsMs = buffer.readBigInt64LE(35);
        if (tsMs > 0n) exchangeTs = Number(tsMs / 1000n);
      } catch {}

      // LTP in paise (8 bytes int64 / 100)
      let ltp = 0;
      try {
        const ltpPaise = buffer.readBigInt64LE(43);
        ltp = Number(ltpPaise) / 100.0;
      } catch {}

      // Volume (8 bytes int64 at byte 67)
      let volume = 0;
      if (buffer.length >= 75) {
        try {
          volume = Number(buffer.readBigInt64LE(67));
        } catch {}
      }

      if (tokenStr && ltp > 0) {
        this.emitTick(tokenStr, ltp, volume, exchangeTs);
      }
    } catch {}
  }

  private static emitTick(token: string, ltp: number, volume: number, timestamp: number): void {
    const info = this.tokenToSymbol.get(token);
    const symbol = info ? info.symbol : token;
    const exchange = info ? info.exchange : 'NSE';

    const tick: AngelOneQuoteTick = {
      token,
      symbol,
      exchange,
      price: Number(ltp.toFixed(2)),
      volume,
      timestamp,
    };

    for (const listener of this.listeners) {
      try {
        listener(tick);
      } catch {}
    }
  }

  /**
   * Fetch historical candles in chunks from Angel One
   */
  public static async fetchHistoricalCandles(
    symbol: string,
    interval: string,
    fromTimestamp: number,
    toTimestamp: number
  ): Promise<AngelOneHistoricalCandle[] | null> {
    if (!this.isConfigured()) return null;
    const authed = await this.ensureLoggedIn();
    if (!authed || !this.jwtToken) return null;

    const tokenInfo = this.resolveToken(symbol);
    if (!tokenInfo) return null;

    let smartInterval = 'FIFTEEN_MINUTE';
    let chunkSeconds = 30 * 86400; // 30 days max for intraday

    switch (interval.toLowerCase()) {
      case '1m':
        smartInterval = 'ONE_MINUTE';
        chunkSeconds = 30 * 86400;
        break;
      case '5m':
        smartInterval = 'FIVE_MINUTE';
        chunkSeconds = 60 * 86400;
        break;
      case '15m':
        smartInterval = 'FIFTEEN_MINUTE';
        chunkSeconds = 90 * 86400;
        break;
      case '30m':
        smartInterval = 'THIRTY_MINUTE';
        chunkSeconds = 90 * 86400;
        break;
      case '1h':
        smartInterval = 'ONE_HOUR';
        chunkSeconds = 180 * 86400;
        break;
      case '1d':
        smartInterval = 'ONE_DAY';
        chunkSeconds = 365 * 86400;
        break;
      default:
        smartInterval = 'FIFTEEN_MINUTE';
        chunkSeconds = 90 * 86400;
    }

    const allCandles: AngelOneHistoricalCandle[] = [];
    let currentFrom = fromTimestamp;

    while (currentFrom < toTimestamp) {
      const currentTo = Math.min(currentFrom + chunkSeconds, toTimestamp);
      const fromStr = new Date(currentFrom * 1000).toISOString().replace('T', ' ').substring(0, 16);
      const toStr = new Date(currentTo * 1000).toISOString().replace('T', ' ').substring(0, 16);

      try {
        const url = 'https://apiconnect.angelone.in/rest/secure/angelbroking/historical/v1/getCandleData';
        const res = await fetch(url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': this.jwtToken,
            'X-PrivateKey': config.angelOneApiKey,
            'X-UserType': 'USER',
            'X-SourceID': 'WEB',
            'X-ClientLocalIP': '127.0.0.1',
            'X-ClientPublicIP': '127.0.0.1',
            'X-MACAddress': '00:00:00:00:00:00',
          },
          body: JSON.stringify({
            exchange: tokenInfo.exchange,
            symboltoken: tokenInfo.token,
            interval: smartInterval,
            fromdate: fromStr,
            todate: toStr,
          }),
          signal: AbortSignal.timeout(6000),
        });

        if (res.ok) {
          const json = (await res.json()) as any;
          if (json?.status && Array.isArray(json?.data)) {
            for (const item of json.data) {
              // item format: [timestampStr, open, high, low, close, volume]
              const ts = Math.floor(new Date(item[0]).getTime() / 1000);
              allCandles.push({
                timestamp: ts,
                open: parseFloat(item[1]),
                high: parseFloat(item[2]),
                low: parseFloat(item[3]),
                close: parseFloat(item[4]),
                volume: parseInt(item[5], 10) || 0,
              });
            }
          }
        }
      } catch {
        break;
      }

      currentFrom = currentTo + 1;
    }

    if (allCandles.length > 0) {
      allCandles.sort((a, b) => a.timestamp - b.timestamp);
      return allCandles;
    }
    return null;
  }
}
