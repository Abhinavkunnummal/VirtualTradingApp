import express, { Response } from 'express';
import { z } from 'zod';
import { requireAuth, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { PaperAccount, Holding, Order, LedgerEntry } from '../../models';
import { config } from '../../config';

export const paperAccountRouter = express.Router();

const ResetCapitalSchema = z.object({
  startingCapital: z.number().min(100000).max(100000000).default(1000000),
  resetPortfolio: z.boolean().default(true),
});

const TopUpCapitalSchema = z.object({
  amount: z.number().positive('Top-up amount must be positive').min(1000, 'Minimum top-up is INR 1,000').max(10000000, 'Maximum top-up is INR 1,00,00,000'),
  idempotencyKey: z.string().optional(),
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
