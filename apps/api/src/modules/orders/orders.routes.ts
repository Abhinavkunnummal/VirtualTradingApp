import express, { Response } from 'express';
import { z } from 'zod';
import { requireAuth, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { PaperTradingEngine } from './paperEngine.service';
import { Order, Execution, LedgerEntry, Holding, TradeHistory } from '../../models';
import { RealtimeMarketService } from '../market-data/realtimeMarket.service';
import { MarketDataService } from '../market-data/marketData.service';

export const ordersRouter = express.Router();

const SquareOffSchema = z.object({
  quantity: z.number().int().positive().optional(),
  orderType: z.enum(['MARKET', 'LIMIT']).default('MARKET'),
  limitPrice: z.number().positive().optional(),
});

const SubmitOrderSchema = z.object({
  symbol: z.string().min(1, 'Symbol is required').trim().toUpperCase(),
  exchange: z.enum(['NSE', 'BSE', 'MCX', 'US', 'CRYPTO']).default('NSE'),
  side: z.enum(['BUY', 'SELL']),
  orderType: z.enum(['MARKET', 'LIMIT', 'SL', 'SL_M']),
  product: z.enum(['CNC', 'MIS']).default('CNC'),
  quantity: z.number().int().positive('Quantity must be greater than zero'),
  limitPrice: z.number().positive().optional(),
  triggerPrice: z.number().positive().optional(),
  idempotencyKey: z.string().optional(),

  // Advanced order parameters
  orderVariety: z.enum(['REGULAR', 'BRACKET', 'COVER', 'AMO']).default('REGULAR'),
  targetPrice: z.number().positive().optional(),
  stopLossPrice: z.number().positive().optional(),
  trailingStopLoss: z.number().positive().optional(),
});

// POST /api/v1/orders
ordersRouter.post('/', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const validated = SubmitOrderSchema.parse(req.body);

    const result = await PaperTradingEngine.submitOrder({
      userId: req.user!.userId,
      symbol: validated.symbol,
      exchange: validated.exchange,
      side: validated.side,
      orderType: validated.orderType,
      product: validated.product,
      quantity: validated.quantity,
      limitPrice: validated.limitPrice,
      triggerPrice: validated.triggerPrice,
      idempotencyKey: validated.idempotencyKey,
      orderVariety: validated.orderVariety,
      targetPrice: validated.targetPrice,
      stopLossPrice: validated.stopLossPrice,
      trailingStopLoss: validated.trailingStopLoss,
    });

    return res.status(201).json({
      success: true,
      message: result.message,
      order: {
        id: result.order._id.toString(),
        symbol: result.order.symbol,
        exchange: result.order.exchange,
        side: result.order.side,
        orderType: result.order.orderType,
        product: result.order.product,
        orderVariety: result.order.orderVariety,
        bracketLegType: result.order.bracketLegType,
        quantity: result.order.quantity,
        filledQuantity: result.order.filledQuantity,
        limitPrice: result.order.limitPrice,
        triggerPrice: result.order.triggerPrice,
        targetPrice: result.order.targetPrice,
        stopLossPrice: result.order.stopLossPrice,
        trailingStopLoss: result.order.trailingStopLoss,
        averagePrice: result.order.averagePrice,
        status: result.order.status,
        createdAt: result.order.createdAt,
      },
      childLegs: (result.childLegs || []).map((leg: any) => ({
        id: leg._id.toString(),
        symbol: leg.symbol,
        side: leg.side,
        orderType: leg.orderType,
        bracketLegType: leg.bracketLegType,
        limitPrice: leg.limitPrice,
        triggerPrice: leg.triggerPrice,
        trailingStopLoss: leg.trailingStopLoss,
        status: leg.status,
      })),
      execution: result.execution
        ? {
            id: result.execution._id.toString(),
            executionPrice: result.execution.executionPrice,
            executedQuantity: result.execution.executedQuantity,
            fees: result.execution.fees,
            slippage: result.execution.slippage,
            isSimulated: result.execution.isSimulated,
            timestamp: result.execution.timestamp,
          }
        : null,
    });
  } catch (err: any) {
    if (
      err.message?.includes('Insufficient') ||
      err.message?.includes('not available') ||
      err.message?.includes('Bracket') ||
      err.message?.includes('Cover') ||
      err.message?.includes('Trailing')
    ) {
      return res.status(400).json({ success: false, message: err.message });
    }
    return next(err);
  }
});

// GET /api/v1/orders
ordersRouter.get('/', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const { status, symbol, product, orderVariety } = req.query as {
      status?: string;
      symbol?: string;
      product?: string;
      orderVariety?: string;
    };

    const filter: any = { userId: req.user!.userId };
    if (status) filter.status = status;
    if (symbol) filter.symbol = symbol.toUpperCase();
    if (product) filter.product = product;
    if (orderVariety) filter.orderVariety = orderVariety;

    const orders = await Order.find(filter).sort({ createdAt: -1 }).limit(100);

    return res.status(200).json({
      success: true,
      count: orders.length,
      orders: orders.map((o) => ({
        id: o._id.toString(),
        symbol: o.symbol,
        exchange: o.exchange,
        side: o.side,
        orderType: o.orderType,
        product: o.product,
        orderVariety: o.orderVariety,
        bracketLegType: o.bracketLegType,
        parentOrderId: o.parentOrderId ? o.parentOrderId.toString() : null,
        quantity: o.quantity,
        filledQuantity: o.filledQuantity,
        limitPrice: o.limitPrice,
        triggerPrice: o.triggerPrice,
        targetPrice: o.targetPrice,
        stopLossPrice: o.stopLossPrice,
        trailingStopLoss: o.trailingStopLoss,
        averagePrice: o.averagePrice,
        status: o.status,
        rejectionReason: o.rejectionReason,
        createdAt: o.createdAt,
      })),
    });
  } catch (err) {
    return next(err);
  }
});

// GET /api/v1/orders/executions/history
ordersRouter.get('/executions/history', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const executions = await Execution.find({ userId: req.user!.userId })
      .sort({ timestamp: -1 })
      .limit(100);

    return res.status(200).json({
      success: true,
      count: executions.length,
      executions: executions.map((e) => ({
        id: e._id.toString(),
        orderId: e.orderId.toString(),
        executionPrice: e.executionPrice,
        executedQuantity: e.executedQuantity,
        fees: e.fees,
        slippage: e.slippage,
        isSimulated: e.isSimulated,
        priceSource: e.priceSource,
        timestamp: e.timestamp,
      })),
    });
  } catch (err) {
    return next(err);
  }
});

// GET /api/v1/orders/account/ledger
ordersRouter.get('/account/ledger', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const ledger = await LedgerEntry.find({ userId: req.user!.userId })
      .sort({ timestamp: -1 })
      .limit(100);

    return res.status(200).json({
      success: true,
      count: ledger.length,
      entries: ledger.map((l) => ({
        id: l._id.toString(),
        orderId: l.orderId?.toString() || null,
        type: l.type,
        amount: l.amount,
        balanceAfter: l.balanceAfter,
        description: l.description,
        timestamp: l.createdAt,
      })),
    });
  } catch (err) {
    return next(err);
  }
});

// POST /api/v1/orders/:id/cancel
ordersRouter.post('/:id/cancel', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const result = await PaperTradingEngine.cancelOrder(req.user!.userId, req.params.id as string);
    return res.status(200).json(result);
  } catch (err: any) {
    if (err.message?.includes('not found') || err.message?.includes('access denied')) {
      return res.status(404).json({ success: false, message: err.message });
    }
    if (err.message?.includes('Cannot cancel')) {
      return res.status(400).json({ success: false, message: err.message });
    }
    return next(err);
  }
});

// DELETE /api/v1/orders/:id (Cancel Order)
ordersRouter.delete('/:id', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const result = await PaperTradingEngine.cancelOrder(req.user!.userId, req.params.id as string);
    return res.status(200).json(result);
  } catch (err: any) {
    if (err.message?.includes('not found') || err.message?.includes('access denied')) {
      return res.status(404).json({ success: false, message: err.message });
    }
    if (err.message?.includes('Cannot cancel')) {
      return res.status(400).json({ success: false, message: err.message });
    }
    return next(err);
  }
});

// GET /api/v1/orders/:id/executions
ordersRouter.get('/:id/executions', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const order = await Order.findOne({ _id: req.params.id as string, userId: req.user!.userId });
    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    const executions = await Execution.find({ orderId: order._id }).sort({ timestamp: -1 });

    return res.status(200).json({
      success: true,
      count: executions.length,
      executions: executions.map((e) => ({
        id: e._id.toString(),
        orderId: e.orderId.toString(),
        executionPrice: e.executionPrice,
        executedQuantity: e.executedQuantity,
        fees: e.fees,
        slippage: e.slippage,
        isSimulated: e.isSimulated,
        priceSource: e.priceSource,
        timestamp: e.timestamp,
      })),
    });
  } catch (err) {
    return next(err);
  }
});

// GET /api/v1/orders/:id/audit-trail
ordersRouter.get('/:id/audit-trail', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const order = await Order.findOne({ _id: req.params.id as string, userId: req.user!.userId });
    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    const ledgers = await LedgerEntry.find({ orderId: order._id }).sort({ createdAt: 1 });
    const executions = await Execution.find({ orderId: order._id }).sort({ timestamp: 1 });

    return res.status(200).json({
      success: true,
      orderId: order._id.toString(),
      symbol: order.symbol,
      history: {
        orderPlacedAt: order.createdAt,
        finalStatus: order.status,
        rejectionReason: order.rejectionReason,
        executions: executions.map((e) => ({
          price: e.executionPrice,
          quantity: e.executedQuantity,
          fees: e.fees,
          slippage: e.slippage,
          timestamp: e.timestamp,
        })),
        ledgerImpacts: ledgers.map((l) => ({
          type: l.type,
          amount: l.amount,
          balanceAfter: l.balanceAfter,
          description: l.description,
          timestamp: l.createdAt,
        })),
      },
    });
  } catch (err) {
    return next(err);
  }
});

// POST /api/v1/orders/positions/:symbol/square-off
ordersRouter.post('/positions/:symbol/square-off', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const validated = SquareOffSchema.parse(req.body);
    const result = await PaperTradingEngine.squareOffPosition({
      userId: req.user!.userId,
      symbol: req.params.symbol as string,
      quantity: validated.quantity,
      orderType: validated.orderType,
      limitPrice: validated.limitPrice,
    });
    return res.status(200).json(result);
  } catch (err: any) {
    if (err.message?.includes('not found') || err.message?.includes('No open position')) {
      return res.status(404).json({ success: false, message: err.message });
    }
    return next(err);
  }
});

// GET /api/v1/orders/positions & /positions/list
const getPositionsHandler = async (req: AuthenticatedRequest, res: Response, next: any) => {
  try {
    const holdings = await Holding.find({ userId: req.user!.userId, quantity: { $gt: 0 } });
    const positions = await Promise.all(
      holdings.map(async (h) => {
        let ltp = h.averageCost;
        if (process.env.NODE_ENV !== 'test') {
          const live = await RealtimeMarketService.getLiveQuote(h.symbol).catch(() => null);
          if (live && live.price > 0) ltp = live.price;
          else {
            const symQuote = MarketDataService.getQuote(h.symbol);
            if (symQuote && symQuote.price > 0) ltp = symQuote.price;
          }
        }
        const invested = parseFloat((h.quantity * h.averageCost).toFixed(2));
        const current = parseFloat((h.quantity * ltp).toFixed(2));
        const pnl = parseFloat((current - invested).toFixed(2));
        const pnlPercent = invested > 0 ? parseFloat(((pnl / invested) * 100).toFixed(2)) : 0;

        return {
          id: h._id.toString(),
          symbol: h.symbol,
          exchange: h.exchange,
          product: h.product || 'CNC',
          side: 'BUY',
          quantity: h.quantity,
          averagePrice: h.averageCost,
          ltp,
          investedValue: invested,
          currentValue: current,
          unrealizedPnl: pnl,
          unrealizedPnlPercent: pnlPercent,
          stopLoss: h.stopLossPrice || null,
          targetPrice: h.targetPrice || null,
          createdAt: h.createdAt,
        };
      })
    );

    return res.status(200).json({
      success: true,
      count: positions.length,
      positions,
    });
  } catch (err) {
    return next(err);
  }
};
ordersRouter.get('/positions', requireAuth, getPositionsHandler);
ordersRouter.get('/positions/list', requireAuth, getPositionsHandler);

// GET /api/v1/orders/history & /history/closed-trades
const getHistoryHandler = async (req: AuthenticatedRequest, res: Response, next: any) => {
  try {
    const page = parseInt(req.query.page as string || '1', 10);
    const limit = Math.min(parseInt(req.query.limit as string || '50', 10), 100);
    const skip = (page - 1) * limit;

    const total = await TradeHistory.countDocuments({ userId: req.user!.userId });
    const trades = await TradeHistory.find({ userId: req.user!.userId })
      .sort({ closedAt: -1 })
      .skip(skip)
      .limit(limit);

    return res.status(200).json({
      success: true,
      total,
      page,
      limit,
      trades: trades.map((t) => ({
        id: t._id.toString(),
        symbol: t.symbol,
        exchange: t.exchange,
        product: t.product,
        side: t.side,
        quantity: t.quantity,
        entryPrice: t.entryPrice,
        exitPrice: t.exitPrice,
        realizedPnl: t.realizedPnl,
        realizedPnlPercent: t.realizedPnlPercent,
        fees: t.fees,
        closedAt: t.closedAt,
      })),
    });
  } catch (err) {
    return next(err);
  }
};
ordersRouter.get('/history', requireAuth, getHistoryHandler);
ordersRouter.get('/history/closed-trades', requireAuth, getHistoryHandler);

// GET /api/v1/orders/summary/pnl
ordersRouter.get('/summary/pnl', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const trades = await TradeHistory.find({ userId: req.user!.userId });
    let totalRealizedPnl = 0;
    let profitableTrades = 0;
    trades.forEach((t) => {
      totalRealizedPnl += t.realizedPnl;
      if (t.realizedPnl > 0) profitableTrades++;
    });

    const holdings = await Holding.find({ userId: req.user!.userId, quantity: { $gt: 0 } });
    let totalUnrealizedPnl = 0;
    for (const h of holdings) {
      let ltp = h.averageCost;
      const symQuote = MarketDataService.getQuote(h.symbol);
      if (symQuote && symQuote.price > 0) ltp = symQuote.price;
      totalUnrealizedPnl += (ltp - h.averageCost) * h.quantity;
    }

    const totalTrades = trades.length;
    const winRate = totalTrades > 0 ? parseFloat(((profitableTrades / totalTrades) * 100).toFixed(1)) : 0;

    return res.status(200).json({
      success: true,
      summary: {
        totalRealizedPnl: parseFloat(totalRealizedPnl.toFixed(2)),
        totalUnrealizedPnl: parseFloat(totalUnrealizedPnl.toFixed(2)),
        totalPnl: parseFloat((totalRealizedPnl + totalUnrealizedPnl).toFixed(2)),
        totalTrades,
        profitableTrades,
        winRate,
      },
    });
  } catch (err) {
    return next(err);
  }
});

// GET /api/v1/orders/:id
ordersRouter.get('/:id', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const order = await Order.findOne({ _id: req.params.id as string, userId: req.user!.userId });
    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    const executions = await Execution.find({ orderId: order._id }).sort({ timestamp: -1 });
    const childLegs = await Order.find({ parentOrderId: order._id });

    return res.status(200).json({
      success: true,
      order: {
        id: order._id.toString(),
        symbol: order.symbol,
        exchange: order.exchange,
        side: order.side,
        orderType: order.orderType,
        product: order.product,
        orderVariety: order.orderVariety,
        bracketLegType: order.bracketLegType,
        parentOrderId: order.parentOrderId ? order.parentOrderId.toString() : null,
        quantity: order.quantity,
        filledQuantity: order.filledQuantity,
        limitPrice: order.limitPrice,
        triggerPrice: order.triggerPrice,
        targetPrice: order.targetPrice,
        stopLossPrice: order.stopLossPrice,
        trailingStopLoss: order.trailingStopLoss,
        averagePrice: order.averagePrice,
        status: order.status,
        rejectionReason: order.rejectionReason,
        createdAt: order.createdAt,
      },
      executions: executions.map((e) => ({
        id: e._id.toString(),
        executionPrice: e.executionPrice,
        executedQuantity: e.executedQuantity,
        fees: e.fees,
        slippage: e.slippage,
        isSimulated: e.isSimulated,
        timestamp: e.timestamp,
      })),
      childLegs: childLegs.map((l) => ({
        id: l._id.toString(),
        bracketLegType: l.bracketLegType,
        side: l.side,
        status: l.status,
        limitPrice: l.limitPrice,
        triggerPrice: l.triggerPrice,
      })),
      execution: executions.length > 0
        ? {
            id: executions[0]._id.toString(),
            executionPrice: executions[0].executionPrice,
            executedQuantity: executions[0].executedQuantity,
            fees: executions[0].fees,
            slippage: executions[0].slippage,
            isSimulated: executions[0].isSimulated,
            timestamp: executions[0].timestamp,
          }
        : null,
    });
  } catch (err) {
    return next(err);
  }
});
