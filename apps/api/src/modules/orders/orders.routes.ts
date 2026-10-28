import express, { Response } from 'express';
import { z } from 'zod';
import { requireAuth, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { PaperTradingEngine } from './paperEngine.service';
import { Order, Execution, LedgerEntry } from '../../models';

export const ordersRouter = express.Router();

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
        quantity: result.order.quantity,
        filledQuantity: result.order.filledQuantity,
        limitPrice: result.order.limitPrice,
        triggerPrice: result.order.triggerPrice,
        averagePrice: result.order.averagePrice,
        status: result.order.status,
        createdAt: result.order.createdAt,
      },
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
    if (err.message?.includes('Insufficient') || err.message?.includes('not available')) {
      return res.status(400).json({ success: false, message: err.message });
    }
    return next(err);
  }
});

// GET /api/v1/orders
ordersRouter.get('/', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const { status, symbol, product } = req.query as {
      status?: string;
      symbol?: string;
      product?: string;
    };

    const filter: any = { userId: req.user!.userId };
    if (status) filter.status = status;
    if (symbol) filter.symbol = symbol.toUpperCase();
    if (product) filter.product = product;

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
        quantity: o.quantity,
        filledQuantity: o.filledQuantity,
        limitPrice: o.limitPrice,
        triggerPrice: o.triggerPrice,
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

// GET /api/v1/orders/:id
ordersRouter.get('/:id', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const orderId = req.params.id as string;
    const order = await Order.findOne({ _id: orderId, userId: req.user!.userId });
    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found.' });
    }

    const executions = await Execution.find({ orderId: order._id }).sort({ timestamp: 1 });

    return res.status(200).json({
      success: true,
      order: {
        id: order._id.toString(),
        symbol: order.symbol,
        exchange: order.exchange,
        side: order.side,
        orderType: order.orderType,
        product: order.product,
        quantity: order.quantity,
        filledQuantity: order.filledQuantity,
        limitPrice: order.limitPrice,
        triggerPrice: order.triggerPrice,
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
    });
  } catch (err) {
    return next(err);
  }
});

// POST /api/v1/orders/:id/cancel
ordersRouter.post('/:id/cancel', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const orderId = req.params.id as string;
    const result = await PaperTradingEngine.cancelOrder(req.user!.userId, orderId);
    return res.status(200).json(result);
  } catch (err: any) {
    if (err.message?.includes('Cannot cancel') || err.message?.includes('not found')) {
      return res.status(400).json({ success: false, message: err.message });
    }
    return next(err);
  }
});

// GET /api/v1/executions
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

// GET /api/v1/paper-account/ledger
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
        timestamp: l.timestamp,
      })),
    });
  } catch (err) {
    return next(err);
  }
});
