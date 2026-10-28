import mongoose from 'mongoose';
import { PaperAccount, Order, Execution, Holding, LedgerEntry } from '../../models';
import { MarketDataService, MarketQuote } from '../market-data/marketData.service';
import { SocketService } from '../../services/socket.service';

export interface SubmitOrderParams {
  userId: string;
  symbol: string;
  exchange: 'NSE' | 'BSE' | 'MCX' | 'US' | 'CRYPTO';
  side: 'BUY' | 'SELL';
  orderType: 'MARKET' | 'LIMIT' | 'SL' | 'SL_M';
  product: 'CNC' | 'MIS';
  quantity: number;
  limitPrice?: number;
  triggerPrice?: number;
  idempotencyKey?: string;
}

export interface FeeBreakdown {
  brokerage: number;
  stt: number;
  exchangeFee: number;
  gst: number;
  totalFeesAndTaxes: number;
  slippage: number;
  executionPrice: number;
}

export class PaperTradingEngine {
  /**
   * Calculates realistic simulated fees, slippage, and execution price.
   */
  static calculateFeesAndSlippage(
    quote: MarketQuote,
    side: 'BUY' | 'SELL',
    product: 'CNC' | 'MIS',
    quantity: number,
    basePrice: number
  ): FeeBreakdown {
    // 1. Slippage calculation
    let slippagePct = 0.0002; // 0.02% base
    if (quote.category === 'CRYPTO') slippagePct = 0.0005; // 0.05%
    if (quote.category === 'COMMODITY') slippagePct = 0.00015;

    // Small impact based on quantity size
    slippagePct += Math.min(quantity * 0.00001, 0.001);

    const slippageAmount = parseFloat((basePrice * slippagePct).toFixed(2));
    const executionPrice =
      side === 'BUY'
        ? parseFloat((basePrice + slippageAmount).toFixed(2))
        : parseFloat((basePrice - slippageAmount).toFixed(2));

    const turnover = executionPrice * quantity;

    // 2. Brokerage (Zerodha style: min(₹20, 0.03%))
    const brokerage = Math.min(20.0, parseFloat((turnover * 0.0003).toFixed(2)));

    // 3. STT (Securities Transaction Tax)
    let stt = 0;
    if (quote.currency === 'INR') {
      if (product === 'CNC') {
        stt = parseFloat((turnover * 0.001).toFixed(2)); // 0.1% on delivery
      } else if (side === 'SELL') {
        stt = parseFloat((turnover * 0.00025).toFixed(2)); // 0.025% on intraday sell
      }
    }

    // 4. Exchange Transaction Fee (~0.00345%)
    const exchangeFee = parseFloat((turnover * 0.0000345).toFixed(2));

    // 5. GST (18% on brokerage + exchange fee)
    const gst = parseFloat(((brokerage + exchangeFee) * 0.18).toFixed(2));

    const totalFeesAndTaxes = parseFloat((brokerage + stt + exchangeFee + gst).toFixed(2));

    return {
      brokerage,
      stt,
      exchangeFee,
      gst,
      totalFeesAndTaxes,
      slippage: slippageAmount,
      executionPrice,
    };
  }

  /**
   * Submits and matches a simulated paper-trading order with server-side validation.
   */
  static async submitOrder(params: SubmitOrderParams) {
    const quote = MarketDataService.getQuote(params.symbol);
    if (!quote) {
      throw new Error(`Symbol ${params.symbol} not available in market master.`);
    }

    // Check idempotency if provided
    if (params.idempotencyKey) {
      const existing = await Order.findOne({ idempotencyKey: params.idempotencyKey });
      if (existing) {
        return { order: existing, execution: null, message: 'Idempotent request: Order already processed.' };
      }
    }

    // Fetch user paper account
    const account = await PaperAccount.findOne({ userId: params.userId });
    if (!account || account.status !== 'ACTIVE') {
      throw new Error('Active paper-trading sandbox account required.');
    }

    const referencePrice = params.limitPrice || quote.price;
    const turnover = referencePrice * params.quantity;
    const estimatedFees = 25.0; // conservative buffer for margin check
    const requiredMargin =
      params.product === 'MIS'
        ? parseFloat((turnover / 5 + estimatedFees).toFixed(2)) // 5x leverage
        : parseFloat((turnover + estimatedFees).toFixed(2)); // 100% cash

    // Validate SELL delivery (CNC) requires sufficient existing holding
    if (params.side === 'SELL' && params.product === 'CNC') {
      const holding = await Holding.findOne({
        userId: params.userId,
        symbol: params.symbol,
      });
      if (!holding || holding.quantity < params.quantity) {
        throw new Error(
          `Insufficient holdings for delivery sell. You own ${holding?.quantity || 0} shares of ${params.symbol}, but attempted to sell ${params.quantity}.`
        );
      }
    }

    // Validate BUY cash/margin availability
    if (params.side === 'BUY') {
      if (account.availableCash < requiredMargin) {
        throw new Error(
          `Insufficient virtual margin. Required: INR ${requiredMargin.toLocaleString('en-IN')}, Available: INR ${account.availableCash.toLocaleString('en-IN')}`
        );
      }
    }

    // Determine execution eligibility based on OrderType
    let canExecuteImmediately = false;
    let baseExecutionPrice = quote.price;

    if (params.orderType === 'MARKET') {
      canExecuteImmediately = true;
      baseExecutionPrice = params.side === 'BUY' ? quote.ask : quote.bid;
    } else if (params.orderType === 'LIMIT' && params.limitPrice) {
      if (params.side === 'BUY' && quote.ask <= params.limitPrice) {
        canExecuteImmediately = true;
        baseExecutionPrice = params.limitPrice;
      } else if (params.side === 'SELL' && quote.bid >= params.limitPrice) {
        canExecuteImmediately = true;
        baseExecutionPrice = params.limitPrice;
      }
    } else if (params.orderType === 'SL_M' && params.triggerPrice) {
      if (params.side === 'BUY' && quote.price >= params.triggerPrice) {
        canExecuteImmediately = true;
        baseExecutionPrice = quote.ask;
      } else if (params.side === 'SELL' && quote.price <= params.triggerPrice) {
        canExecuteImmediately = true;
        baseExecutionPrice = quote.bid;
      }
    }

    // Create the Order Record in DB
    const order = await Order.create({
      userId: params.userId,
      paperAccountId: account._id,
      instrumentId: `${params.exchange}:${params.symbol}`,
      symbol: params.symbol,
      exchange: params.exchange,
      side: params.side,
      orderType: params.orderType,
      product: params.product,
      quantity: params.quantity,
      filledQuantity: 0,
      limitPrice: params.limitPrice || null,
      triggerPrice: params.triggerPrice || null,
      status: canExecuteImmediately ? 'FILLED' : 'PENDING',
      idempotencyKey: params.idempotencyKey || null,
    });

    if (!canExecuteImmediately) {
      // Pending order: Reserve margin
      if (params.side === 'BUY') {
        account.availableCash = parseFloat((account.availableCash - requiredMargin).toFixed(2));
        account.reservedMargin = parseFloat((account.reservedMargin + requiredMargin).toFixed(2));
        await account.save();

        await LedgerEntry.create({
          userId: params.userId,
          paperAccountId: account._id,
          orderId: order._id,
          type: 'MARGIN_RESERVE',
          amount: -requiredMargin,
          balanceAfter: account.availableCash,
          description: `Margin reserved for ${params.side} ${params.quantity} ${params.symbol} (${params.orderType})`,
        });
      }

      return {
        order,
        execution: null,
        message: `Simulated ${params.orderType} order placed in pending queue. Margin reserved.`,
      };
    }

    // Execute Immediate Fill
    const feeInfo = this.calculateFeesAndSlippage(
      quote,
      params.side,
      params.product,
      params.quantity,
      baseExecutionPrice
    );

    const actualTurnover = parseFloat((feeInfo.executionPrice * params.quantity).toFixed(2));
    const totalCost = parseFloat((actualTurnover + feeInfo.totalFeesAndTaxes).toFixed(2));

    // Update Order to FILLED
    order.status = 'FILLED';
    order.filledQuantity = params.quantity;
    order.averagePrice = feeInfo.executionPrice;
    await order.save();

    // Create Execution Record
    const execution = await Execution.create({
      orderId: order._id,
      userId: params.userId,
      paperAccountId: account._id,
      executionPrice: feeInfo.executionPrice,
      executedQuantity: params.quantity,
      fees: feeInfo.totalFeesAndTaxes,
      slippage: feeInfo.slippage,
      isSimulated: true,
      priceSource: 'SIMULATED_TICK_ENGINE',
      timestamp: new Date(),
    });

    // Update Portfolio Holdings & Cash
    if (params.side === 'BUY') {
      account.availableCash = parseFloat((account.availableCash - totalCost).toFixed(2));
      await account.save();

      await LedgerEntry.create({
        userId: params.userId,
        paperAccountId: account._id,
        orderId: order._id,
        type: 'TRADE_FILL',
        amount: -totalCost,
        balanceAfter: account.availableCash,
        description: `Executed BUY ${params.quantity} ${params.symbol} @ ₹${feeInfo.executionPrice} (Fees: ₹${feeInfo.totalFeesAndTaxes})`,
      });

      // Update Delivery Holding if CNC
      if (params.product === 'CNC') {
        const existingHolding = await Holding.findOne({
          userId: params.userId,
          symbol: params.symbol,
        });

        if (existingHolding) {
          const totalNewQty = existingHolding.quantity + params.quantity;
          const totalNewCost = existingHolding.quantity * existingHolding.averageCost + actualTurnover;
          existingHolding.averageCost = parseFloat((totalNewCost / totalNewQty).toFixed(2));
          existingHolding.quantity = totalNewQty;
          await existingHolding.save();
        } else {
          await Holding.create({
            userId: params.userId,
            paperAccountId: account._id,
            instrumentId: `${params.exchange}:${params.symbol}`,
            symbol: params.symbol,
            exchange: params.exchange,
            quantity: params.quantity,
            averageCost: feeInfo.executionPrice,
          });
        }
      }
    } else {
      // SELL Execution
      const netProceeds = parseFloat((actualTurnover - feeInfo.totalFeesAndTaxes).toFixed(2));
      account.availableCash = parseFloat((account.availableCash + netProceeds).toFixed(2));
      await account.save();

      await LedgerEntry.create({
        userId: params.userId,
        paperAccountId: account._id,
        orderId: order._id,
        type: 'TRADE_FILL',
        amount: netProceeds,
        balanceAfter: account.availableCash,
        description: `Executed SELL ${params.quantity} ${params.symbol} @ ₹${feeInfo.executionPrice} (Net credit: ₹${netProceeds})`,
      });

      // Decrement Delivery Holding if CNC
      if (params.product === 'CNC') {
        const existingHolding = await Holding.findOne({
          userId: params.userId,
          symbol: params.symbol,
        });

        if (existingHolding) {
          if (existingHolding.quantity <= params.quantity) {
            await Holding.deleteOne({ _id: existingHolding._id });
          } else {
            existingHolding.quantity -= params.quantity;
            await existingHolding.save();
          }
        }
      }
    }

    // Emit real-time order update and execution notification to user's isolated private channel
    SocketService.emitToUser(params.userId, 'order_update', {
      orderId: order._id.toString(),
      symbol: order.symbol,
      status: order.status,
      side: order.side,
      quantity: order.quantity,
      filledQuantity: order.filledQuantity,
      averagePrice: order.averagePrice,
      timestamp: new Date().toISOString(),
    });

    SocketService.emitToUser(params.userId, 'execution_notice', {
      orderId: order._id.toString(),
      symbol: params.symbol,
      side: params.side,
      executionPrice: feeInfo.executionPrice,
      executedQuantity: params.quantity,
      fees: feeInfo.totalFeesAndTaxes,
      slippage: feeInfo.slippage,
      timestamp: new Date().toISOString(),
    });

    return {
      order,
      execution,
      message: `Simulated ${params.side} order filled @ ₹${feeInfo.executionPrice.toFixed(2)} (Slippage: ₹${feeInfo.slippage}, Fees: ₹${feeInfo.totalFeesAndTaxes})`,
    };
  }

  /**
   * Cancels a pending simulated order and releases reserved margin back to available cash.
   */
  static async cancelOrder(userId: string, orderId: string) {
    const order = await Order.findOne({ _id: orderId, userId });
    if (!order) {
      throw new Error('Order not found or access denied.');
    }

    if (order.status !== 'PENDING') {
      throw new Error(`Cannot cancel order in ${order.status} state.`);
    }

    const account = await PaperAccount.findOne({ userId });
    if (account && order.side === 'BUY') {
      // Release reserved margin
      const turnover = (order.limitPrice || 0) * order.quantity;
      const marginToRelease =
        order.product === 'MIS' ? parseFloat((turnover / 5 + 25.0).toFixed(2)) : parseFloat((turnover + 25.0).toFixed(2));

      account.availableCash = parseFloat((account.availableCash + marginToRelease).toFixed(2));
      account.reservedMargin = parseFloat(Math.max(0, account.reservedMargin - marginToRelease).toFixed(2));
      await account.save();

      await LedgerEntry.create({
        userId,
        paperAccountId: account._id,
        orderId: order._id,
        type: 'MARGIN_RELEASE',
        amount: marginToRelease,
        balanceAfter: account.availableCash,
        description: `Released reserved margin for cancelled BUY order #${order._id.toString().slice(-6)}`,
      });
    }

    order.status = 'CANCELLED';
    order.rejectionReason = 'Cancelled by user';
    await order.save();

    // Emit real-time cancellation notice to user's isolated private channel
    SocketService.emitToUser(userId, 'order_update', {
      orderId: order._id.toString(),
      symbol: order.symbol,
      status: 'CANCELLED',
      side: order.side,
      timestamp: new Date().toISOString(),
    });

    return {
      success: true,
      order,
      message: 'Simulated order cancelled and reserved margin released.',
    };
  }
}
