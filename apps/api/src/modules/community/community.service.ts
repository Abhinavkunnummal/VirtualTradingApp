import mongoose from 'mongoose';
import { CommunityRoom, CommunityMessage, ICommunityRoom, ICommunityMessage } from '../../models';
import { SocketService } from '../../services/socket.service';

const DEFAULT_ROOMS = [
  {
    roomId: 'room:general',
    name: 'Live Trading Floor',
    description: 'General community discussion, market sentiment & trading setups.',
    category: 'GENERAL' as const,
    memberCount: 1420,
    isPrivate: false,
  },
  {
    roomId: 'room:nifty',
    name: 'NIFTY & Equities Desk',
    description: 'NSE / BSE index futures, stock delivery ideas & technical breakouts.',
    category: 'EQUITIES' as const,
    memberCount: 890,
    isPrivate: false,
  },
  {
    roomId: 'room:crypto',
    name: 'Crypto 24/7 Floor',
    description: 'Continuous Bitcoin, Ethereum, and crypto paper trading setups.',
    category: 'CRYPTO' as const,
    memberCount: 650,
    isPrivate: false,
  },
  {
    roomId: 'room:commodities',
    name: 'MCX Gold & Crude Hub',
    description: 'Commodity futures, MCX Gold 1KG, Crude Oil simulation strategies.',
    category: 'COMMODITIES' as const,
    memberCount: 410,
    isPrivate: false,
  },
  {
    roomId: 'room:ai_insights',
    name: 'AI Insights & Educational Feed',
    description: 'Automated AI market summaries, educational deep-dives & trade risk reviews.',
    category: 'AI_INSIGHTS' as const,
    memberCount: 1100,
    isPrivate: false,
  },
];

export class CommunityService {
  /**
   * Initializes baseline default public discussion rooms idempotently.
   */
  static async seedDefaultRooms(): Promise<void> {
    for (const r of DEFAULT_ROOMS) {
      await CommunityRoom.findOneAndUpdate(
        { roomId: r.roomId },
        { $setOnInsert: r },
        { upsert: true, new: true }
      );
    }
  }

  /**
   * Retrieves list of all public and instrument discussion rooms.
   */
  static async getRooms(): Promise<ICommunityRoom[]> {
    await this.seedDefaultRooms();
    return CommunityRoom.find().sort({ memberCount: -1 });
  }

  /**
   * Retrieves paginated messages for a given room.
   */
  static async getRoomMessages(
    roomId: string,
    limit: number = 50,
    before?: string
  ): Promise<ICommunityMessage[]> {
    const query: Record<string, unknown> = { roomId };
    if (before) {
      query.createdAt = { $lt: new Date(before) };
    }

    const messages = await CommunityMessage.find(query)
      .sort({ createdAt: -1 })
      .limit(Math.min(limit, 100));

    return messages.reverse(); // Return in chronological order
  }

  /**
   * Sanitizes text to protect against injection and links
   */
  static sanitizeContent(content: string): string {
    return content
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
      .replace(/[<>]/g, '')
      .trim();
  }

  /**
   * Posts a new message into a community room.
   */
  static async createMessage(params: {
    roomId: string;
    userId: string;
    authorName: string;
    content: string;
    type?: 'CHAT' | 'EDUCATIONAL' | 'AI_SUMMARY' | 'SYSTEM';
    tradeTag?: string;
    sentiment?: 'BULLISH' | 'BEARISH' | 'NEUTRAL';
    isAiGenerated?: boolean;
  }): Promise<ICommunityMessage> {
    const sanitized = this.sanitizeContent(params.content);
    if (!sanitized || sanitized.length === 0) {
      throw new Error('Message content cannot be empty.');
    }

    const message = await CommunityMessage.create({
      roomId: params.roomId,
      userId: new mongoose.Types.ObjectId(params.userId),
      authorName: params.authorName,
      content: sanitized.slice(0, 1000),
      type: params.type || 'CHAT',
      tradeTag: params.tradeTag,
      sentiment: params.sentiment,
      isAiGenerated: params.isAiGenerated || false,
    });

    const payload = {
      id: message._id.toString(),
      roomId: message.roomId,
      userId: params.userId,
      authorName: message.authorName,
      content: message.content,
      type: message.type,
      tradeTag: message.tradeTag,
      sentiment: message.sentiment,
      likesCount: message.likesCount,
      isAiGenerated: message.isAiGenerated,
      createdAt: message.createdAt.toISOString(),
    };

    // Broadcast to active room members in real-time
    SocketService.emitToRoom(params.roomId, 'new_message', payload);

    return message;
  }

  /**
   * Deletes a message under ownership rules (only the author can delete their message).
   */
  static async deleteMessage(userId: string, messageId: string): Promise<boolean> {
    const message = await CommunityMessage.findById(messageId);
    if (!message) {
      throw new Error('Message not found.');
    }

    if (message.userId.toString() !== userId) {
      throw new Error('Unauthorized: You can only delete your own messages.');
    }

    await CommunityMessage.deleteOne({ _id: messageId });

    SocketService.emitToRoom(message.roomId, 'message_deleted', {
      messageId,
      roomId: message.roomId,
    });

    return true;
  }
}
