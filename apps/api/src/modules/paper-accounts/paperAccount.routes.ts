import express, { Response } from 'express';
import { z } from 'zod';
import { requireAuth, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { PaperAccount, Holding, Order, LedgerEntry } from '../../models';
import { config } from '../../config';
import { SocketService } from '../../services/socket.service';

export const paperAccountRouter = express.Router();

const ResetCapitalSchema = z.object({
  startingCapital: z.number().min(0).max(100000000).default(0),
  resetPortfolio: z.boolean().default(true),
});

const TopUpCapitalSchema = z.object({
  amount: z.number().positive('Amount must be positive').min(100, 'Minimum amount is INR 100').max(100000000, 'Maximum amount is INR 10,00,00,000'),
  idempotencyKey: z.string().optional(),
});

const WithdrawCapitalSchema = z.object({
  amount: z.number().positive('Withdrawal amount must be positive').min(100, 'Minimum withdrawal is INR 100'),
});

// GET /api/v1/paper-account
paperAccountRouter.get('/', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    let account = await PaperAccount.findOne({ userId: req.user!.userId });

    if (!account) {
      // Idempotently create if missing
      account = await PaperAccount.create({
        userId: req.user!.userId,
        startingCapital: config.startingCapital,
        availableCash: config.startingCapital,
        reservedMargin: 0,
        baseCurrency: 'INR',
        isSimulated: true,
      });
    }

    return res.status(200).json({
      success: true,
      account: {
        id: account._id.toString(),
        accountName: account.accountName,
        baseCurrency: account.baseCurrency,
        startingCapital: account.startingCapital,
        availableCash: account.availableCash,
        reservedMargin: account.reservedMargin,
        isSimulated: true,
        disclaimer: 'Fictional capital for paper trading simulation only. No real funds.',
        status: account.status,
        updatedAt: account.updatedAt,
      },
    });
  } catch (err) {
    return next(err);
  }
});

// POST /api/v1/paper-account/reset
paperAccountRouter.post('/reset', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const { startingCapital, resetPortfolio } = ResetCapitalSchema.parse(req.body);

    const account = await PaperAccount.findOneAndUpdate(
      { userId: req.user!.userId },
      {
        startingCapital,
        availableCash: startingCapital,
        reservedMargin: 0,
        status: 'ACTIVE',
      },
      { new: true, upsert: true }
    );

    if (resetPortfolio) {
      // Clear holdings and open orders for fresh simulation
      await Holding.deleteMany({ userId: req.user!.userId });
      await Order.updateMany(
        { userId: req.user!.userId, status: 'PENDING' },
        { status: 'CANCELLED', rejectionReason: 'Sandbox reset by user' }
      );
    }

    // Record auditable ledger entry for capital reset
    await LedgerEntry.create({
      userId: req.user!.userId,
      paperAccountId: account._id,
      type: 'CAPITAL_RESET',
      amount: startingCapital,
      balanceAfter: startingCapital,
      description: `Virtual capital reset to INR ${startingCapital.toLocaleString('en-IN')} by user`,
    });

    return res.status(200).json({
      success: true,
      message: `Sandbox capital reset to INR ${startingCapital.toLocaleString('en-IN')}`,
      account: {
        id: account._id.toString(),
        startingCapital: account.startingCapital,
        availableCash: account.availableCash,
        reservedMargin: account.reservedMargin,
        isSimulated: true,
      },
    });
  } catch (err) {
    return next(err);
  }
});

// POST /api/v1/paper-account/top-up
paperAccountRouter.post('/top-up', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const { amount, idempotencyKey } = TopUpCapitalSchema.parse(req.body);

    let account = await PaperAccount.findOne({ userId: req.user!.userId });
    if (!account) {
      account = await PaperAccount.create({
        userId: req.user!.userId,
        startingCapital: config.startingCapital,
        availableCash: config.startingCapital,
        reservedMargin: 0,
        baseCurrency: 'INR',
        isSimulated: true,
      });
    }

    // Check idempotency if key provided
    if (idempotencyKey) {
      const existingEntry = await LedgerEntry.findOne({
        userId: req.user!.userId,
        description: { $regex: new RegExp(`idemp:${idempotencyKey}`) },
      });
      if (existingEntry) {
        return res.status(200).json({
          success: true,
          message: `Idempotent request: Virtual funds already credited.`,
          account: {
            id: account._id.toString(),
            availableCash: account.availableCash,
            reservedMargin: account.reservedMargin,
            isSimulated: true,
          },
        });
      }
    }

    const updatedAccount = await PaperAccount.findOneAndUpdate(
      { _id: account._id },
      { $inc: { availableCash: amount } },
      { new: true }
    );

    const description = idempotencyKey
      ? `Virtual fund top-up of INR ${amount.toLocaleString('en-IN')} [idemp:${idempotencyKey}]`
      : `Virtual fund top-up of INR ${amount.toLocaleString('en-IN')}`;

    await LedgerEntry.create({
      userId: req.user!.userId,
      paperAccountId: account._id,
      type: 'CAPITAL_TOPUP',
      amount,
      balanceAfter: updatedAccount!.availableCash,
      description,
    });

    SocketService.emitToUser(req.user!.userId.toString(), 'portfolio_update', {
      availableCash: updatedAccount!.availableCash,
      reservedMargin: updatedAccount!.reservedMargin,
      timestamp: new Date().toISOString(),
    });

    return res.status(200).json({
      success: true,
      message: `Successfully credited INR ${amount.toLocaleString('en-IN')} in virtual practice funds.`,
      account: {
        id: updatedAccount!._id.toString(),
        availableCash: updatedAccount!.availableCash,
        reservedMargin: updatedAccount!.reservedMargin,
        isSimulated: true,
      },
    });
  } catch (err) {
    return next(err);
  }
});

// POST /api/v1/paper-account/add-funds (alias for top-up)
paperAccountRouter.post('/add-funds', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const { amount, idempotencyKey } = TopUpCapitalSchema.parse(req.body);

    let account = await PaperAccount.findOne({ userId: req.user!.userId });
    if (!account) {
      account = await PaperAccount.create({
        userId: req.user!.userId,
        startingCapital: config.startingCapital,
        availableCash: config.startingCapital,
        reservedMargin: 0,
        baseCurrency: 'INR',
        isSimulated: true,
      });
    }

    if (idempotencyKey) {
      const existingEntry = await LedgerEntry.findOne({
        userId: req.user!.userId,
        description: { $regex: new RegExp(`idemp:${idempotencyKey}`) },
      });
      if (existingEntry) {
        return res.status(200).json({
          success: true,
          message: `Idempotent request: Virtual funds already credited.`,
          account: {
            id: account._id.toString(),
            availableCash: account.availableCash,
            reservedMargin: account.reservedMargin,
            isSimulated: true,
          },
        });
      }
    }

    const updatedAccount = await PaperAccount.findOneAndUpdate(
      { _id: account._id },
      { $inc: { availableCash: amount, startingCapital: amount } },
      { new: true }
    );

    const description = idempotencyKey
      ? `Virtual fund deposit of INR ${amount.toLocaleString('en-IN')} [idemp:${idempotencyKey}]`
      : `Virtual fund deposit of INR ${amount.toLocaleString('en-IN')}`;

    await LedgerEntry.create({
      userId: req.user!.userId,
      paperAccountId: account._id,
      type: 'CAPITAL_TOPUP',
      amount,
      balanceAfter: updatedAccount!.availableCash,
      description,
    });

    SocketService.emitToUser(req.user!.userId.toString(), 'portfolio_update', {
      availableCash: updatedAccount!.availableCash,
      reservedMargin: updatedAccount!.reservedMargin,
      timestamp: new Date().toISOString(),
    });

    return res.status(200).json({
      success: true,
      message: `Successfully added INR ${amount.toLocaleString('en-IN')} to virtual wallet.`,
      account: {
        id: updatedAccount!._id.toString(),
        availableCash: updatedAccount!.availableCash,
        reservedMargin: updatedAccount!.reservedMargin,
        isSimulated: true,
      },
    });
  } catch (err) {
    return next(err);
  }
});

// POST /api/v1/paper-account/withdraw
paperAccountRouter.post('/withdraw', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const { amount } = WithdrawCapitalSchema.parse(req.body);

    const account = await PaperAccount.findOne({ userId: req.user!.userId });
    if (!account) {
      return res.status(404).json({ success: false, message: 'Paper trading account not found.' });
    }

    if (account.availableCash < amount) {
      return res.status(400).json({
        success: false,
        message: `Insufficient available cash to withdraw. Available: INR ${account.availableCash.toLocaleString('en-IN')}, Requested: INR ${amount.toLocaleString('en-IN')}`,
      });
    }

    const updatedAccount = await PaperAccount.findOneAndUpdate(
      { _id: account._id },
      { $inc: { availableCash: -amount, startingCapital: -amount } },
      { new: true }
    );

    await LedgerEntry.create({
      userId: req.user!.userId,
      paperAccountId: account._id,
      type: 'CAPITAL_WITHDRAW',
      amount: -amount,
      balanceAfter: updatedAccount!.availableCash,
      description: `Virtual fund withdrawal of INR ${amount.toLocaleString('en-IN')}`,
    });

    SocketService.emitToUser(req.user!.userId.toString(), 'portfolio_update', {
      availableCash: updatedAccount!.availableCash,
      reservedMargin: updatedAccount!.reservedMargin,
      timestamp: new Date().toISOString(),
    });

    return res.status(200).json({
      success: true,
      message: `Successfully withdrew INR ${amount.toLocaleString('en-IN')} from virtual wallet.`,
      account: {
        id: updatedAccount!._id.toString(),
        availableCash: updatedAccount!.availableCash,
        reservedMargin: updatedAccount!.reservedMargin,
        isSimulated: true,
      },
    });
  } catch (err) {
    return next(err);
  }
});

// GET /api/v1/paper-account/transactions
paperAccountRouter.get('/transactions', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const page = parseInt(req.query.page as string || '1', 10);
    const limit = Math.min(parseInt(req.query.limit as string || '50', 10), 100);
    const skip = (page - 1) * limit;

    const total = await LedgerEntry.countDocuments({ userId: req.user!.userId });
    const entries = await LedgerEntry.find({ userId: req.user!.userId })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    return res.status(200).json({
      success: true,
      total,
      page,
      limit,
      transactions: entries.map((e) => ({
        id: e._id.toString(),
        type: e.type,
        amount: e.amount,
        balanceAfter: e.balanceAfter,
        description: e.description,
        timestamp: e.createdAt,
      })),
    });
  } catch (err) {
    return next(err);
  }
});
