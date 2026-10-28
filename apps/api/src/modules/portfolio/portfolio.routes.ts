import express, { Response } from 'express';
import { requireAuth, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { PaperAccount, Holding, Order } from '../../models';

export const portfolioRouter = express.Router();

// Mock price lookup table for demo / test consistency
const MOCK_PRICES: Record<string, number> = {
  'RELIANCE': 2945.50,
  'HDFCBANK': 1720.80,
  'TCS': 4120.00,
  'INFY': 1885.20,
  'BTC/USDT': 67420.00,
  'ETH/USDT': 2540.00,
  'GOLD 1KG': 78450.00,
};

// GET /api/v1/portfolio
portfolioRouter.get('/', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const account = await PaperAccount.findOne({ userId: req.user!.userId });
    if (!account) {
      return res.status(404).json({ success: false, message: 'Paper account not found.' });
    }

    const holdings = await Holding.find({ userId: req.user!.userId });

    let totalInvested = 0;
    let totalCurrentValue = 0;

    const formattedHoldings = holdings.map((h) => {
      const ltp = MOCK_PRICES[h.symbol] || h.averageCost;
      const invested = h.quantity * h.averageCost;
      const current = h.quantity * ltp;
      const pnl = current - invested;
      const pnlPercent = invested > 0 ? (pnl / invested) * 100 : 0;

      totalInvested += invested;
      totalCurrentValue += current;

      return {
        id: h._id.toString(),
        symbol: h.symbol,
        exchange: h.exchange,
        quantity: h.quantity,
        averageBuyPrice: h.averageCost,
        ltp,
        investedValue: invested,
        currentValue: current,
        unrealizedPnl: pnl,
        unrealizedPnlPercent: parseFloat(pnlPercent.toFixed(2)),
      };
    });

    const totalPortfolioValue = account.availableCash + totalCurrentValue;
    const totalPnl = totalPortfolioValue - account.startingCapital;
    const totalPnlPercent = account.startingCapital > 0
      ? (totalPnl / account.startingCapital) * 100
      : 0;

    return res.status(200).json({
      success: true,
      portfolio: {
        totalPortfolioValue,
        availableCash: account.availableCash,
        investedValue: totalInvested,
        startingCapital: account.startingCapital,
        totalPnl,
        totalPnlPercent: parseFloat(totalPnlPercent.toFixed(2)),
        isSimulated: true,
        holdings: formattedHoldings,
      },
    });
  } catch (err) {
    return next(err);
  }
});

// GET /api/v1/orders
portfolioRouter.get('/orders', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const status = req.query.status as string | undefined;
    const filter: any = { userId: req.user!.userId };
    if (status) {
      filter.status = status;
    }

    const orders = await Order.find(filter).sort({ createdAt: -1 }).limit(50);

    return res.status(200).json({
      success: true,
      orders: orders.map((o) => ({
        id: o._id.toString(),
        symbol: o.symbol,
        exchange: o.exchange,
        side: o.side,
        orderType: o.orderType,
        product: o.product,
        quantity: o.quantity,
        filledQuantity: o.filledQuantity,
        limitPrice: o.limitPrice,
        triggerPrice: o.triggerPrice,
        averagePrice: o.averagePrice,
        status: o.status,
        createdAt: o.createdAt,
      })),
    });
  } catch (err) {
    return next(err);
  }
});
