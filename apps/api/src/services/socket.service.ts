import { Server as SocketIOServer, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import { CommunityMessage } from '../models';

export interface AuthenticatedSocket extends Socket {
  data: {
    userId?: string;
    email?: string;
  };
}

export class SocketService {
  private static io: SocketIOServer | null = null;

  static init(serverIo: SocketIOServer): void {
    this.io = serverIo;

    // Authentication middleware
    this.io.use((socket: AuthenticatedSocket, next) => {
      const authHeader = socket.handshake.headers?.authorization;
      const rawToken = socket.handshake.auth?.token || (authHeader ? authHeader.replace(/^Bearer\s+/i, '') : null);

      if (rawToken) {
        try {
          const payload = jwt.verify(rawToken, config.jwtAccessSecret) as { userId: string; email: string };
          socket.data.userId = payload.userId;
          socket.data.email = payload.email;
        } catch {
          // Token is invalid/expired - socket connects in guest mode
          socket.data.userId = undefined;
          socket.data.email = undefined;
        }
      }
      next();
    });

    this.io.on('connection', (socket: AuthenticatedSocket) => {
      const userId = socket.data.userId;

      // Automatically join user's private isolation room if authenticated
      if (userId) {
        socket.join(`user:${userId}`);
      }

      // Handle joining discussion rooms with strict boundary isolation
      socket.on('join_room', (data: { roomId: string }) => {
        if (!data?.roomId || typeof data.roomId !== 'string') return;
        const cleanRoom = data.roomId.replace(/^room:/, '').trim();

        // Security Barrier: Disallow joining private user channels or path traversal
        if (cleanRoom.startsWith('user:') || cleanRoom.includes('..') || cleanRoom.includes('/')) {
          socket.emit('error_event', { message: 'Unauthorized room subscription attempt.' });
          return;
        }

        const roomName = `room:${cleanRoom}`;
        socket.join(roomName);
        socket.emit('joined_room', { roomId: cleanRoom, status: 'success' });
      });

      // Handle leaving discussion rooms
      socket.on('leave_room', (data: { roomId: string }) => {
        if (!data?.roomId || typeof data.roomId !== 'string') return;
        const cleanRoom = data.roomId.replace(/^room:/, '').trim();
        socket.leave(`room:${cleanRoom}`);
      });

      // Handle subscribing to ticker price stream
      socket.on('join_ticker', (data: { symbols: string[] }) => {
        if (Array.isArray(data?.symbols)) {
          for (const sym of data.symbols) {
            socket.join(`ticker:${sym.toUpperCase()}`);
          }
        }
      });

      // Handle unsubscribing from ticker price stream
      socket.on('leave_ticker', (data: { symbols: string[] }) => {
        if (Array.isArray(data?.symbols)) {
          for (const sym of data.symbols) {
            socket.leave(`ticker:${sym.toUpperCase()}`);
          }
        }
      });

      // Handle subscribing to candle bar stream
      socket.on('join_candles', (data: { symbol: string; interval: string }) => {
        if (data?.symbol && data?.interval) {
          socket.join(`candles:${data.symbol.toUpperCase()}:${data.interval.toLowerCase()}`);
        }
      });

      // Handle unsubscribing from candle bar stream
      socket.on('leave_candles', (data: { symbol: string; interval: string }) => {
        if (data?.symbol && data?.interval) {
          socket.leave(`candles:${data.symbol.toUpperCase()}:${data.interval.toLowerCase()}`);
        }
      });

      // Handle real-time chat messages
      socket.on(
        'send_message',
        async (data: {
          roomId: string;
          content: string;
          authorName?: string;
          tradeTag?: string;
          sentiment?: 'BULLISH' | 'BEARISH' | 'NEUTRAL';
        }) => {
          if (!socket.data.userId) {
            socket.emit('error_event', { message: 'Authentication required to post messages.' });
            return;
          }

          if (!data?.roomId || !data?.content || data.content.trim().length === 0) {
            socket.emit('error_event', { message: 'Message content and room are required.' });
            return;
          }

          try {
            const author = data.authorName || socket.data.email?.split('@')[0] || 'Trader';
            const message = await CommunityMessage.create({
              roomId: data.roomId,
              userId: socket.data.userId,
              authorName: author,
              content: data.content.trim().slice(0, 1000),
              type: 'CHAT',
              tradeTag: data.tradeTag,
              sentiment: data.sentiment,
              isAiGenerated: false,
            });

            const payload = {
              id: message._id.toString(),
              roomId: message.roomId,
              userId: socket.data.userId,
              authorName: message.authorName,
              content: message.content,
              type: message.type,
              tradeTag: message.tradeTag,
              sentiment: message.sentiment,
              likesCount: message.likesCount,
              isAiGenerated: message.isAiGenerated,
              createdAt: message.createdAt.toISOString(),
            };

            // Broadcast to all participants in that room
            SocketService.emitToRoom(data.roomId, 'new_message', payload);
          } catch (err) {
            socket.emit('error_event', { message: 'Failed to send message.' });
          }
        }
      );

      socket.on('disconnect', () => {
        // Cleaned up automatically by Socket.IO
      });
    });
  }

  /**
   * Emits private event strictly to a specific user's private channel.
   * Other users cannot listen to or access this data.
   */
  static emitToUser(userId: string, event: string, data: unknown): void {
    if (!this.io) return;
    this.io.to(`user:${userId}`).emit(event, data);
  }

  /**
   * Emits public event to all participants of a community room.
   */
  static emitToRoom(roomId: string, event: string, data: unknown): void {
    if (!this.io) return;
    this.io.to(`room:${roomId}`).emit(event, data);
  }

  /**
   * Emits simulated ticker price update to subscribers.
   */
  static emitTickerUpdate(symbol: string, data: unknown): void {
    if (!this.io) return;
    this.io.to(`ticker:${symbol.toUpperCase()}`).emit('ticker_tick', data);
  }

  /**
   * Emits real-time candle bar update to subscribers.
   */
  static emitCandleUpdate(symbol: string, interval: string, data: unknown): void {
    if (!this.io) return;
    this.io.to(`candles:${symbol.toUpperCase()}:${interval.toLowerCase()}`).emit('candle_update', data);
  }

  /**
   * Getter for the Socket.IO server instance.
   */
  static getIO(): SocketIOServer | null {
    return this.io;
  }
}
