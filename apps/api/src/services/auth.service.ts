import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { User, RefreshSession, PaperAccount, Watchlist } from '../models';
import { config } from '../config';

const SALT_ROUNDS = process.env.NODE_ENV === 'test' ? 6 : 12;
const ACCESS_TOKEN_EXPIRY = '15m';
const REFRESH_TOKEN_EXPIRY_DAYS = 7;

export interface TokenPayload {
  userId: string;
  email: string;
}

export class AuthService {
  static async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, SALT_ROUNDS);
  }

  static async comparePassword(password: string, hash: string): Promise<boolean> {
    return bcrypt.compare(password, hash);
  }

  static hashToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  static generateAccessToken(userId: string, email: string): string {
    return jwt.sign({ userId, email } as TokenPayload, config.jwtAccessSecret, {
      expiresIn: ACCESS_TOKEN_EXPIRY,
    });
  }

  static generateRefreshToken(): string {
    return crypto.randomBytes(40).toString('hex');
  }

  static verifyAccessToken(token: string): TokenPayload {
    return jwt.verify(token, config.jwtAccessSecret) as TokenPayload;
  }

  static async registerUser(data: {
    email: string;
    password: string;
    displayName: string;
    startingCapital?: number;
    userAgent?: string;
    ipAddress?: string;
  }) {
    const normalizedEmail = data.email.toLowerCase().trim();

    // Check existing user
    const existing = await User.findOne({ email: normalizedEmail });
    if (existing) {
      throw new Error('An account with this email address already exists.');
    }

    // Hash password
    const passwordHash = await this.hashPassword(data.password);

    // Create User
    const user = await User.create({
      email: normalizedEmail,
      passwordHash,
      displayName: data.displayName.trim(),
    });

    // Idempotently create Paper Account with starting capital
    const capital = data.startingCapital || config.startingCapital;
    const existingAccount = await PaperAccount.findOne({ userId: user._id });
    let paperAccount = existingAccount;
    if (!existingAccount) {
      paperAccount = await PaperAccount.create({
        userId: user._id,
        startingCapital: capital,
        availableCash: capital,
        reservedMargin: 0,
        baseCurrency: 'INR',
        isSimulated: true,
      });
    }

    // Create default watchlist
    await Watchlist.findOneAndUpdate(
      { userId: user._id, name: 'Default Watchlist' },
      {
        $setOnInsert: {
          userId: user._id,
          name: 'Default Watchlist',
          instruments: ['RELIANCE', 'HDFCBANK', 'TCS', 'BTC/USDT'],
          isDefault: true,
        },
      },
      { upsert: true }
    );

    // Generate tokens & session
    const accessToken = this.generateAccessToken(user._id.toString(), user.email);
    const rawRefreshToken = this.generateRefreshToken();
    const tokenHash = this.hashToken(rawRefreshToken);

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + REFRESH_TOKEN_EXPIRY_DAYS);

    await RefreshSession.create({
      userId: user._id,
      tokenHash,
      expiresAt,
      userAgent: data.userAgent || null,
      ipAddress: data.ipAddress || null,
    });

    return {
      user: {
        id: user._id.toString(),
        email: user.email,
        displayName: user.displayName,
        experienceLevel: user.experienceLevel,
        paperAccountId: paperAccount!._id.toString(),
        createdAt: user.createdAt,
      },
      accessToken,
      refreshToken: rawRefreshToken,
    };
  }

  static async loginUser(data: {
    email: string;
    password: string;
    userAgent?: string;
    ipAddress?: string;
  }) {
    const normalizedEmail = data.email.toLowerCase().trim();

    const user = await User.findOne({ email: normalizedEmail });
    if (!user) {
      // Timing-safe non-leaking message
      throw new Error('Invalid email or password.');
    }

    const isValid = await this.comparePassword(data.password, user.passwordHash);
    if (!isValid) {
      throw new Error('Invalid email or password.');
    }

    // Ensure paper account exists
    let paperAccount = await PaperAccount.findOne({ userId: user._id });
    if (!paperAccount) {
      paperAccount = await PaperAccount.create({
        userId: user._id,
        startingCapital: config.startingCapital,
        availableCash: config.startingCapital,
        reservedMargin: 0,
        baseCurrency: 'INR',
        isSimulated: true,
      });
    }

    // Generate tokens
    const accessToken = this.generateAccessToken(user._id.toString(), user.email);
    const rawRefreshToken = this.generateRefreshToken();
    const tokenHash = this.hashToken(rawRefreshToken);

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + REFRESH_TOKEN_EXPIRY_DAYS);

    await RefreshSession.create({
      userId: user._id,
      tokenHash,
      expiresAt,
      userAgent: data.userAgent || null,
      ipAddress: data.ipAddress || null,
    });

    return {
      user: {
        id: user._id.toString(),
        email: user.email,
        displayName: user.displayName,
        experienceLevel: user.experienceLevel,
        paperAccountId: paperAccount._id.toString(),
      },
      accessToken,
      refreshToken: rawRefreshToken,
    };
  }

  static async refreshSession(data: {
    refreshToken: string;
    userAgent?: string;
    ipAddress?: string;
  }) {
    const tokenHash = this.hashToken(data.refreshToken);

    const session = await RefreshSession.findOne({
      tokenHash,
      revokedAt: null,
      expiresAt: { $gt: new Date() },
    });

    if (!session) {
      throw new Error('Invalid or expired refresh token.');
    }

    const user = await User.findById(session.userId);
    if (!user || user.status !== 'ACTIVE') {
      throw new Error('User not found or account is suspended.');
    }

    // Revoke old session (Rotation)
    session.revokedAt = new Date();
    await session.save();

    // Generate new tokens & new session
    const newAccessToken = this.generateAccessToken(user._id.toString(), user.email);
    const newRawRefreshToken = this.generateRefreshToken();
    const newTokenHash = this.hashToken(newRawRefreshToken);

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + REFRESH_TOKEN_EXPIRY_DAYS);

    await RefreshSession.create({
      userId: user._id,
      tokenHash: newTokenHash,
      expiresAt,
      userAgent: data.userAgent || session.userAgent || null,
      ipAddress: data.ipAddress || session.ipAddress || null,
    });

    return {
      accessToken: newAccessToken,
      refreshToken: newRawRefreshToken,
    };
  }

  static async logoutUser(refreshToken: string) {
    if (!refreshToken) return;
    const tokenHash = this.hashToken(refreshToken);
    await RefreshSession.findOneAndUpdate(
      { tokenHash, revokedAt: null },
      { revokedAt: new Date() }
    );
  }
}
