import mongoose from 'mongoose';
import { PaperAccount, Order, Execution, Holding, LedgerEntry, IOrder } from '../../models';
import { MarketDataService, MarketQuote } from '../market-data/marketData.service';
import { RealtimeMarketService } from '../market-data/realtimeMarket.service';
import { SocketService } from '../../services/socket.service';
import { NotificationService } from '../notifications/notification.service';

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

  // Advanced order parameters
  orderVariety?: 'REGULAR' | 'BRACKET' | 'COVER' | 'AMO';
  bracketLegType?: 'ENTRY' | 'TARGET' | 'STOP_LOSS';
  parentOrderId?: string | mongoose.Types.ObjectId;
  targetPrice?: number;
  stopLossPrice?: number;
  trailingStopLoss?: number;
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
    const variety = params.orderVariety || 'REGULAR';
    let quote: MarketQuote | null = null;
    if (process.env.NODE_ENV !== 'test') {
      quote = await RealtimeMarketService.getLiveQuote(params.symbol).catch(() => null);
    }
    if (!quote) {
      quote = MarketDataService.getQuote(params.symbol);
    }
    if (!quote) {
      throw new Error(`Symbol ${params.symbol} not available in market master or live feed.`);
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

    // Validate Cover Order parameters
    if (variety === 'COVER') {
      if (!params.stopLossPrice) {
        throw new Error('Cover order requires a mandatory stop-loss trigger price (stopLossPrice).');
      }
      if (params.side === 'BUY' && params.stopLossPrice >= referencePrice) {
        throw new Error(`Cover order stop-loss trigger (₹${params.stopLossPrice}) must be lower than entry price (₹${referencePrice}).`);
      }
      if (params.side === 'SELL' && params.stopLossPrice <= referencePrice) {
        throw new Error(`Cover order stop-loss trigger (₹${params.stopLossPrice}) must be higher than entry price (₹${referencePrice}).`);
      }
    }

    // Validate Bracket Order parameters
    if (variety === 'BRACKET') {
      if (!params.targetPrice || !params.stopLossPrice) {
        throw new Error('Bracket order requires both targetPrice and stopLossPrice.');
      }
      if (params.side === 'BUY') {
        if (params.targetPrice <= referencePrice) {
          throw new Error(`Bracket target price (₹${params.targetPrice}) must be higher than entry price (₹${referencePrice}).`);
        }
        if (params.stopLossPrice >= referencePrice) {
          throw new Error(`Bracket stop-loss price (₹${params.stopLossPrice}) must be lower than entry price (₹${referencePrice}).`);
        }
      } else {
        if (params.targetPrice >= referencePrice) {
          throw new Error(`Bracket target price (₹${params.targetPrice}) must be lower than entry price (₹${referencePrice}).`);
        }
        if (params.stopLossPrice <= referencePrice) {
          throw new Error(`Bracket stop-loss price (₹${params.stopLossPrice}) must be higher than entry price (₹${referencePrice}).`);
        }
      }

      if (params.trailingStopLoss !== undefined && params.trailingStopLoss <= 0) {
        throw new Error('Trailing stop-loss step must be a positive value.');
      }
    }

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

    // Validate BUY or Intraday SELL (MIS Short) cash/margin availability
    if (params.side === 'BUY' || (params.side === 'SELL' && params.product === 'MIS')) {
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
      ...(params.idempotencyKey ? { idempotencyKey: params.idempotencyKey } : {}),

      // Advanced order variety metadata
      orderVariety: variety,
      bracketLegType: params.bracketLegType || (variety === 'REGULAR' ? null : 'ENTRY'),
      parentOrderId: params.parentOrderId || null,
      targetPrice: params.targetPrice || null,
      stopLossPrice: params.stopLossPrice || null,
      trailingStopLoss: params.trailingStopLoss || null,
      highestObservedPrice: quote.price,
      lowestObservedPrice: quote.price,
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
        childLegs: [],
        message: `Simulated ${variety} ${params.orderType} order placed in pending queue. Margin reserved.`,
      };
    }

    // Execute Immediate Fill
    return this.executeOrderFill(order, account, quote, baseExecutionPrice, false);
  }

  /**
   * Completes an order fill, updates ledger and portfolio, emits events, and spawns/clears child legs.
   */
  private static async executeOrderFill(
    order: IOrder,
    account: any,
    quote: MarketQuote,
    baseExecutionPrice: number,
    wasPending: boolean
  ) {
    const feeInfo = this.calculateFeesAndSlippage(
      quote,
      order.side,
      order.product,
      order.quantity,
      baseExecutionPrice
    );

    const actualTurnover = parseFloat((feeInfo.executionPrice * order.quantity).toFixed(2));
    const totalCost = parseFloat((actualTurnover + feeInfo.totalFeesAndTaxes).toFixed(2));

    // Release previously reserved margin if this was pending
    if (wasPending && order.side === 'BUY') {
      const estimatedReserved =
        order.product === 'MIS'
          ? parseFloat((((order.limitPrice || quote.price) * order.quantity) / 5 + 25.0).toFixed(2))
          : parseFloat((((order.limitPrice || quote.price) * order.quantity) + 25.0).toFixed(2));

      account.availableCash = parseFloat((account.availableCash + estimatedReserved).toFixed(2));
      account.reservedMargin = parseFloat(Math.max(0, account.reservedMargin - estimatedReserved).toFixed(2));
      await account.save();

      await LedgerEntry.create({
        userId: order.userId,
        paperAccountId: account._id,
        orderId: order._id,
        type: 'MARGIN_RELEASE',
        amount: estimatedReserved,
        balanceAfter: account.availableCash,
        description: `Released reserved margin prior to execution fill #${order._id.toString().slice(-6)}`,
      });
    }

    // Update Order to FILLED
    order.status = 'FILLED';
    order.filledQuantity = order.quantity;
    order.averagePrice = feeInfo.executionPrice;
    await order.save();

    // Create Execution Record
    const execution = await Execution.create({
      orderId: order._id,
      userId: order.userId,
      paperAccountId: account._id,
      executionPrice: feeInfo.executionPrice,
      executedQuantity: order.quantity,
      fees: feeInfo.totalFeesAndTaxes,
      slippage: feeInfo.slippage,
      isSimulated: true,
      priceSource: 'SIMULATED_TICK_ENGINE',
      timestamp: new Date(),
    });

    // Update Portfolio Holdings & Cash
    if (order.side === 'BUY') {
      account.availableCash = parseFloat((account.availableCash - totalCost).toFixed(2));
      await account.save();

      await LedgerEntry.create({
        userId: order.userId,
        paperAccountId: account._id,
        orderId: order._id,
        type: 'TRADE_FILL',
        amount: -totalCost,
        balanceAfter: account.availableCash,
        description: `Executed BUY ${order.quantity} ${order.symbol} @ ₹${feeInfo.executionPrice} (Fees: ₹${feeInfo.totalFeesAndTaxes})`,
      });

      // Update Delivery Holding if CNC
      if (order.product === 'CNC') {
        let retries = 5;
        while (retries > 0) {
          try {
            const existingHolding = await Holding.findOne({
              userId: order.userId,
              symbol: order.symbol,
            });

            if (existingHolding) {
              const totalNewQty = existingHolding.quantity + order.quantity;
              const totalNewCost = existingHolding.quantity * existingHolding.averageCost + actualTurnover;
              existingHolding.averageCost = parseFloat((totalNewCost / totalNewQty).toFixed(2));
              existingHolding.quantity = totalNewQty;
              await existingHolding.save();
            } else {
              await Holding.create({
                userId: order.userId,
                paperAccountId: account._id,
                instrumentId: order.instrumentId,
                symbol: order.symbol,
                exchange: order.exchange,
                quantity: order.quantity,
                averageCost: feeInfo.executionPrice,
              });
            }
            break;
          } catch (err: any) {
            if ((err.code === 11000 || err.message?.includes('E11000')) && retries > 1) {
              retries--;
              await new Promise((res) => setTimeout(res, 25));
              continue;
            }
            throw err;
          }
        }
      }
    } else {
      // SELL Execution
      const netProceeds = parseFloat((actualTurnover - feeInfo.totalFeesAndTaxes).toFixed(2));
      account.availableCash = parseFloat((account.availableCash + netProceeds).toFixed(2));
      await account.save();

      await LedgerEntry.create({
        userId: order.userId,
        paperAccountId: account._id,
        orderId: order._id,
        type: 'TRADE_FILL',
        amount: netProceeds,
        balanceAfter: account.availableCash,
        description: `Executed SELL ${order.quantity} ${order.symbol} @ ₹${feeInfo.executionPrice} (Net credit: ₹${netProceeds})`,
      });

      // Decrement Delivery Holding if CNC
      if (order.product === 'CNC') {
        const existingHolding = await Holding.findOne({
          userId: order.userId,
          symbol: order.symbol,
        });

        if (existingHolding) {
          if (existingHolding.quantity <= order.quantity) {
            await Holding.deleteOne({ _id: existingHolding._id });
          } else {
            existingHolding.quantity -= order.quantity;
            await existingHolding.save();
          }
        }
      }
    }

    const conciseNotification = `${order.side} ${order.quantity} ${order.symbol} — Paper order filled`;

    // Emit real-time order update and execution notification to user's isolated private channel
    SocketService.emitToUser(order.userId.toString(), 'order_update', {
      orderId: order._id.toString(),
      symbol: order.symbol,
      status: order.status,
      side: order.side,
      quantity: order.quantity,
      filledQuantity: order.filledQuantity,
      averagePrice: order.averagePrice,
      orderVariety: order.orderVariety,
      bracketLegType: order.bracketLegType,
      timestamp: new Date().toISOString(),
    });

    SocketService.emitToUser(order.userId.toString(), 'execution_notice', {
      orderId: order._id.toString(),
      symbol: order.symbol,
      side: order.side,
      executionPrice: feeInfo.executionPrice,
      executedQuantity: order.quantity,
      fees: feeInfo.totalFeesAndTaxes,
      slippage: feeInfo.slippage,
      notification: conciseNotification,
      timestamp: new Date().toISOString(),
    });

    SocketService.emitToUser(order.userId.toString(), 'portfolio_update', {
      availableCash: account.availableCash,
      reservedMargin: account.reservedMargin,
      timestamp: new Date().toISOString(),
    });

    // Send persistent in-app notification
    await NotificationService.send({
      userId: order.userId,
      title: `Order Filled: ${order.side} ${order.quantity} ${order.symbol}`,
      message: `Executed @ ₹${feeInfo.executionPrice.toFixed(2)}. ${conciseNotification}`,
      type: 'ORDER_FILL',
      data: {
        orderId: order._id.toString(),
        symbol: order.symbol,
        side: order.side,
        averagePrice: feeInfo.executionPrice,
        fees: feeInfo.totalFeesAndTaxes,
      },
    });

    // Spawn child legs for Cover or Bracket Entry orders
    const childLegs: IOrder[] = [];
    const oppositeSide = order.side === 'BUY' ? 'SELL' : 'BUY';

    if (order.orderVariety === 'COVER' && order.bracketLegType === 'ENTRY' && order.stopLossPrice) {
      // Spawn Cover Stop-Loss Leg
      const slLeg = await Order.create({
        userId: order.userId,
        paperAccountId: account._id,
        instrumentId: order.instrumentId,
        symbol: order.symbol,
        exchange: order.exchange,
        side: oppositeSide,
        orderType: 'SL_M',
        product: order.product,
        quantity: order.quantity,
        triggerPrice: order.stopLossPrice,
        status: 'PENDING',
        orderVariety: 'COVER',
        bracketLegType: 'STOP_LOSS',
        parentOrderId: order._id,
        highestObservedPrice: feeInfo.executionPrice,
        lowestObservedPrice: feeInfo.executionPrice,
      });
      childLegs.push(slLeg);

      await NotificationService.send({
        userId: order.userId,
        title: `Cover Stop-Loss Active: ${order.symbol}`,
        message: `Cover SL trigger placed at ₹${order.stopLossPrice} to protect position.`,
        type: 'ORDER_FILL',
        data: { orderId: slLeg._id.toString(), triggerPrice: order.stopLossPrice },
      });
    } else if (order.orderVariety === 'BRACKET' && order.bracketLegType === 'ENTRY' && order.targetPrice && order.stopLossPrice) {
      // Spawn Bracket Target Leg
      const targetLeg = await Order.create({
        userId: order.userId,
        paperAccountId: account._id,
        instrumentId: order.instrumentId,
        symbol: order.symbol,
        exchange: order.exchange,
        side: oppositeSide,
        orderType: 'LIMIT',
        product: order.product,
        quantity: order.quantity,
        limitPrice: order.targetPrice,
        status: 'PENDING',
        orderVariety: 'BRACKET',
        bracketLegType: 'TARGET',
        parentOrderId: order._id,
      });
      childLegs.push(targetLeg);

      // Spawn Bracket Stop-Loss Leg (with optional trailing)
      const slLeg = await Order.create({
        userId: order.userId,
        paperAccountId: account._id,
        instrumentId: order.instrumentId,
        symbol: order.symbol,
        exchange: order.exchange,
        side: oppositeSide,
        orderType: 'SL_M',
        product: order.product,
        quantity: order.quantity,
        triggerPrice: order.stopLossPrice,
        trailingStopLoss: order.trailingStopLoss || null,
        highestObservedPrice: feeInfo.executionPrice,
        lowestObservedPrice: feeInfo.executionPrice,
        status: 'PENDING',
        orderVariety: 'BRACKET',
        bracketLegType: 'STOP_LOSS',
        parentOrderId: order._id,
      });
      childLegs.push(slLeg);

      await NotificationService.send({
        userId: order.userId,
        title: `Bracket Order Active: ${order.symbol}`,
        message: `Target Profit: ₹${order.targetPrice} | Stop-Loss: ₹${order.stopLossPrice}${order.trailingStopLoss ? ` (Trailing: ₹${order.trailingStopLoss})` : ''}`,
        type: 'ORDER_FILL',
        data: {
          targetOrderId: targetLeg._id.toString(),
          slOrderId: slLeg._id.toString(),
          targetPrice: order.targetPrice,
          stopLossPrice: order.stopLossPrice,
        },
      });
    }

    // OCO (One-Cancels-the-Other) Handler:
    // If this executed order was a Bracket child leg (TARGET or STOP_LOSS), cancel sibling leg!
    if (order.parentOrderId && order.orderVariety === 'BRACKET' && (order.bracketLegType === 'TARGET' || order.bracketLegType === 'STOP_LOSS')) {
      const siblingLeg = await Order.findOne({
        parentOrderId: order.parentOrderId,
        _id: { $ne: order._id },
        status: 'PENDING',
      });

      if (siblingLeg) {
        siblingLeg.status = 'CANCELLED';
        siblingLeg.rejectionReason = `Cancelled: Sibling ${order.bracketLegType} leg filled (OCO)`;
        await siblingLeg.save();

        SocketService.emitToUser(order.userId.toString(), 'order_update', {
          orderId: siblingLeg._id.toString(),
          symbol: siblingLeg.symbol,
          status: 'CANCELLED',
          side: siblingLeg.side,
          bracketLegType: siblingLeg.bracketLegType,
          reason: siblingLeg.rejectionReason,
          timestamp: new Date().toISOString(),
        });

        await NotificationService.send({
          userId: order.userId,
          title: `Bracket Order Completed (OCO): ${order.symbol}`,
          message: `${order.bracketLegType} leg filled @ ₹${feeInfo.executionPrice}. Sibling ${siblingLeg.bracketLegType} automatically cancelled.`,
          type: 'BRACKET_OCO',
          data: {
            filledOrderId: order._id.toString(),
            cancelledOrderId: siblingLeg._id.toString(),
            filledLeg: order.bracketLegType,
          },
        });
      }
    }

    return {
      order,
      execution,
      childLegs,
      message: `Simulated ${order.side} order filled @ ₹${feeInfo.executionPrice.toFixed(2)} (Slippage: ₹${feeInfo.slippage}, Fees: ₹${feeInfo.totalFeesAndTaxes})`,
      conciseNotification,
    };
  }

  /**
   * Evaluates pending orders against the latest simulated market tick.
   * Handles dynamic Trailing Stop-Loss ratcheting and OCO execution.
   */
  static async evaluateOpenOrders(symbol: string, quote: MarketQuote) {
    const pendingOrders = await Order.find({ symbol, status: 'PENDING' });
    if (!pendingOrders.length) return;

    for (const order of pendingOrders) {
      try {
        const account = await PaperAccount.findById(order.paperAccountId);
        if (!account || account.status !== 'ACTIVE') continue;

        // 1. Dynamic Trailing Stop-Loss Ratcheting
        if (order.trailingStopLoss && order.bracketLegType === 'STOP_LOSS' && order.triggerPrice) {
          if (order.side === 'SELL') {
            // Position was LONG (BUY entry). SL leg is SELL.
            // When market price climbs above highest observed, ratchet trigger price up.
            const highest = order.highestObservedPrice ?? quote.price;
            if (quote.price > highest) {
              const delta = quote.price - highest;
              if (delta >= order.trailingStopLoss) {
                const steps = Math.floor(delta / order.trailingStopLoss);
                const ratchet = steps * order.trailingStopLoss;
                order.triggerPrice = parseFloat((order.triggerPrice + ratchet).toFixed(2));
                order.highestObservedPrice = quote.price;
                await order.save();

                await NotificationService.send({
                  userId: order.userId,
                  title: `Trailing Stop-Loss Ratcheted: ${order.symbol}`,
                  message: `New stop-loss trigger raised to ₹${order.triggerPrice} following upward move to ₹${quote.price}.`,
                  type: 'TRAILING_STOP',
                  data: { orderId: order._id.toString(), triggerPrice: order.triggerPrice },
                });
              }
            }
          } else if (order.side === 'BUY') {
            // Position was SHORT (MIS SELL entry). SL leg is BUY.
            // When market price drops below lowest observed, ratchet trigger price down.
            const lowest = order.lowestObservedPrice ?? quote.price;
            if (quote.price < lowest) {
              const delta = lowest - quote.price;
              if (delta >= order.trailingStopLoss) {
                const steps = Math.floor(delta / order.trailingStopLoss);
                const ratchet = steps * order.trailingStopLoss;
                order.triggerPrice = parseFloat((order.triggerPrice - ratchet).toFixed(2));
                order.lowestObservedPrice = quote.price;
                await order.save();

                await NotificationService.send({
                  userId: order.userId,
                  title: `Trailing Stop-Loss Ratcheted: ${order.symbol}`,
                  message: `New stop-loss trigger lowered to ₹${order.triggerPrice} following downward move to ₹${quote.price}.`,
                  type: 'TRAILING_STOP',
                  data: { orderId: order._id.toString(), triggerPrice: order.triggerPrice },
                });
              }
            }
          }
        }

        // 2. Check if Order Conditions are met to Execute Fill
        let shouldFill = false;
        let execPrice = quote.price;

        if (order.orderType === 'LIMIT' && order.limitPrice) {
          if (order.side === 'BUY' && quote.ask <= order.limitPrice) {
            shouldFill = true;
            execPrice = order.limitPrice;
          } else if (order.side === 'SELL' && quote.bid >= order.limitPrice) {
            shouldFill = true;
            execPrice = order.limitPrice;
          }
        } else if (order.orderType === 'SL_M' && order.triggerPrice) {
          if (order.side === 'BUY' && quote.price >= order.triggerPrice) {
            shouldFill = true;
            execPrice = quote.ask;
          } else if (order.side === 'SELL' && quote.price <= order.triggerPrice) {
            shouldFill = true;
            execPrice = quote.bid;
          }
        }

        if (shouldFill) {
          await this.executeOrderFill(order, account, quote, execPrice, true);
        }
      } catch (err: any) {
        console.error(`Error evaluating open order ${order._id}:`, err?.message || err);
      }
    }
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
    if (account && order.side === 'BUY' && order.bracketLegType !== 'STOP_LOSS' && order.bracketLegType !== 'TARGET') {
      // Release reserved margin for regular BUY orders
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

    await NotificationService.send({
      userId,
      title: `Order Cancelled: ${order.symbol}`,
      message: `Your pending ${order.side} ${order.quantity} ${order.symbol} order has been cancelled.`,
      type: 'ORDER_CANCEL',
      data: { orderId: order._id.toString(), symbol: order.symbol },
    });

    return {
      success: true,
      order,
      message: 'Simulated order cancelled and reserved margin released.',
    };
  }
}
