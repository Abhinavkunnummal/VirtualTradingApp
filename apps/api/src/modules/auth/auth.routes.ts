import express, { Response } from 'express';
import { z } from 'zod';
import { AuthService } from '../../services/auth.service';
import { requireAuth, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { User, PaperAccount } from '../../models';

export const authRouter = express.Router();

const RegisterSchema = z.object({
  email: z.string().email('Please provide a valid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters long'),
  displayName: z.string().min(2, 'Display name must be at least 2 characters long'),
  startingCapital: z.number().min(10000).max(100000000).optional(),
});

const LoginSchema = z.object({
  email: z.string().email('Please provide a valid email address'),
  password: z.string().min(1, 'Password is required'),
});

const RefreshSchema = z.object({
  refreshToken: z.string().min(10, 'Valid refresh token is required'),
});

// Register
authRouter.post('/register', async (req, res: Response, next) => {
  try {
    const validated = RegisterSchema.parse(req.body);
    const result = await AuthService.registerUser({
      ...validated,
      userAgent: req.headers['user-agent'],
      ipAddress: req.ip,
    });

    return res.status(201).json({
      success: true,
      message: 'Registration successful. Virtual paper-trading account initialized.',
      ...result,
    });
  } catch (err: any) {
    if (err.message?.includes('already exists')) {
      return res.status(409).json({ success: false, message: err.message });
    }
    return next(err);
  }
});

// Login
authRouter.post('/login', async (req, res: Response, next) => {
  try {
    const validated = LoginSchema.parse(req.body);
    const result = await AuthService.loginUser({
      ...validated,
      userAgent: req.headers['user-agent'],
      ipAddress: req.ip,
    });

    return res.status(200).json({
      success: true,
      message: 'Login successful.',
      ...result,
    });
  } catch (err: any) {
    if (err.message?.includes('Invalid email or password')) {
      return res.status(401).json({ success: false, message: err.message });
    }
    return next(err);
  }
});

// Refresh
authRouter.post('/refresh', async (req, res: Response, next) => {
  try {
    const validated = RefreshSchema.parse(req.body);
    const result = await AuthService.refreshSession({
      refreshToken: validated.refreshToken,
      userAgent: req.headers['user-agent'],
      ipAddress: req.ip,
    });

    return res.status(200).json({
      success: true,
      message: 'Session refreshed successfully.',
      ...result,
    });
  } catch (err: any) {
    return res.status(401).json({ success: false, message: err.message });
  }
});

// Logout
authRouter.post('/logout', async (req, res: Response, next) => {
  try {
    const refreshToken = req.body.refreshToken;
    if (refreshToken) {
      await AuthService.logoutUser(refreshToken);
    }
    return res.status(200).json({
      success: true,
      message: 'Logged out successfully.',
    });
  } catch (err) {
    return next(err);
  }
});

// Get Current User Profile (me)
authRouter.get('/me', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const user = await User.findById(req.user!.userId).select('-passwordHash');
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    const paperAccount = await PaperAccount.findOne({ userId: user._id });

    return res.status(200).json({
      success: true,
      user: {
        id: user._id.toString(),
        email: user.email,
        displayName: user.displayName,
        experienceLevel: user.experienceLevel,
        preferredMarkets: user.preferredMarkets,
        paperAccountId: paperAccount?._id.toString() || null,
        createdAt: user.createdAt,
      },
    });
  } catch (err) {
    return next(err);
  }
});
