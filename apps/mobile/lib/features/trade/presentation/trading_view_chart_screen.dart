import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/live_ticker_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../markets/domain/market_models.dart';
import '../../portfolio/presentation/providers/portfolio_provider.dart';
import 'providers/order_provider.dart';
import 'widgets/candlestick_chart_view.dart';

class TradingViewChartScreen extends ConsumerStatefulWidget {
  final InstrumentModel? instrument;

  const TradingViewChartScreen({super.key, this.instrument});

  @override
  ConsumerState<TradingViewChartScreen> createState() => _TradingViewChartScreenState();
}

class _TradingViewChartScreenState extends ConsumerState<TradingViewChartScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  double? _lastLtp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sym = widget.instrument?.symbol ?? ref.read(selectedTradeInstrumentProvider).symbol;
      if (sym.isNotEmpty) {
        ref.read(liveQuotesProvider.notifier).trackSymbol(sym);
      }
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerPricePulse(double newPrice) {
    if (_lastLtp != null && _lastLtp != newPrice) {
      _pulseController.forward(from: 0.0).then((_) => _pulseController.reverse());
    }
    _lastLtp = newPrice;
  }

  void _openQuickOrderModal(BuildContext context, InstrumentModel instrument, double ltp, bool isBuy) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _QuickOrderSheet(
        instrument: instrument,
        currentLtp: ltp,
        initialIsBuy: isBuy,
      ),
    );
  }

  void _showTradingViewModal(BuildContext context, InstrumentModel instrument) {
    final tvSymbol = _resolveTvSymbol(instrument.symbol);
    final externalUrl = 'https://in.tradingview.com/chart/3gcDTCUI/?symbol=$tvSymbol';
    final localUrl = 'http://localhost:5000/tradingview?symbol=${instrument.symbol}';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.tvCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.show_chart, color: AppColors.zerodhaBlue, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'TradingView Pro Terminal',
                        style: AppTypography.headlineSm.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.outline),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.tvDarkBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.tvBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('TradingView Symbol:', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.zerodhaBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tvSymbol,
                            style: AppTypography.labelSm.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.zerodhaBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Live Feed Source:', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                        Text('Binance 24/7 Spot / NSE Real-Time', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Indicators Active:', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                        Text('RSI(14), SMA(20), EMA(20), MACD', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.w600, color: AppColors.secondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'TradingView Live Chart Terminal URL',
                style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.tvDarkBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: SelectableText(
                  externalUrl,
                  style: AppTypography.numericTable.copyWith(fontSize: 11, color: AppColors.zerodhaBlue),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.tvDarkBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: SelectableText(
                  localUrl,
                  style: AppTypography.numericTable.copyWith(fontSize: 11, color: AppColors.kiteGreen),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.zerodhaBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('TradingView Terminal ready for $tvSymbol on http://localhost:5000/tradingview'),
                        backgroundColor: AppColors.zerodhaBlue,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Confirm & Use TradingView Terminal', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  String _resolveTvSymbol(String symbol) {
    final clean = symbol.trim().toUpperCase();
    if (clean.contains('BTC')) return 'BINANCE:BTCUSDT';
    if (clean.contains('ETH')) return 'BINANCE:ETHUSDT';
    if (clean.contains('SOL')) return 'BINANCE:SOLUSDT';
    if (clean.contains('DOGE')) return 'BINANCE:DOGEUSDT';
    if (clean.contains('BNB')) return 'BINANCE:BNBUSDT';
    if (clean == 'NIFTY 50' || clean == 'NIFTY') return 'NSE:NIFTY';
    if (clean == 'BANKNIFTY') return 'NSE:BANKNIFTY';
    if (clean == 'FINNIFTY') return 'NSE:FINNIFTY';
    if (clean == 'SENSEX') return 'BSE:SENSEX';
    if (clean.contains('GOLD')) return 'MCX:GOLD1!';
    if (clean.contains('SILVER')) return 'MCX:SILVER1!';
    if (clean.contains('CRUDE')) return 'MCX:CRUDEOIL1!';
    if (clean.contains('NATURALGAS')) return 'MCX:NATURALGAS1!';
    final usEquities = ['AAPL', 'NVDA', 'TSLA', 'MSFT', 'GOOGL', 'AMZN', 'META', 'NFLX', 'AMD', 'COIN', 'SPY'];
    if (usEquities.contains(clean)) return 'NASDAQ:$clean';
    return 'NSE:$clean';
  }

  @override
  Widget build(BuildContext context) {
    final instrument = widget.instrument ?? ref.watch(selectedTradeInstrumentProvider);
    final interval = ref.watch(selectedCandleIntervalProvider);
    final range = ref.watch(selectedHistoryRangeProvider);
    final portfolio = ref.watch(portfolioProvider).valueOrNull;

    if (instrument == null) {
      return Scaffold(
        backgroundColor: AppColors.tvDarkBg,
        appBar: AppBar(
          backgroundColor: AppColors.tvDarkBg,
          title: const Text('TradingView Pro Chart'),
        ),
        body: Center(
          child: Text('No stock selected. Return to Markets to choose an instrument.', style: AppTypography.bodyMd),
        ),
      );
    }

    final liveQuote = ref.watch(liveQuoteForSymbolProvider(instrument.symbol));
    final ltp = (liveQuote != null && liveQuote.price > 0) ? liveQuote.price : instrument.price;
    final change = liveQuote != null ? liveQuote.change : instrument.change;
    final changePct = liveQuote != null ? liveQuote.changePercent : instrument.changePercent;
    final isPos = change >= 0;

    _triggerPricePulse(ltp);

    final isCrypto = instrument.symbol.contains('/') || ['BTC', 'ETH', 'SOL'].any((c) => instrument.symbol.contains(c));
    final currency = (isCrypto || instrument.exchange == 'US') ? '\$' : '₹';

    final candlesAsync = ref.watch(candlesProvider(CandleQuery(
      symbol: instrument.symbol,
      interval: interval,
      range: range,
    )));

    // Active position lookup for this stock
    final activeHolding = portfolio?.holdings.where((h) => h.symbol.toUpperCase() == instrument.symbol.toUpperCase()).firstOrNull;
    final hasHolding = activeHolding != null && activeHolding.quantity > 0;
    final holdingInvested = hasHolding ? activeHolding.quantity * activeHolding.averageBuyPrice : 0.0;
    final holdingCurrent = hasHolding ? activeHolding.quantity * ltp : 0.0;
    final holdingPnl = hasHolding ? (holdingCurrent - holdingInvested) : 0.0;
    final holdingPnlPct = (hasHolding && holdingInvested > 0) ? (holdingPnl / holdingInvested) * 100 : 0.0;
    final holdingIsPos = holdingPnl >= 0;

    return Scaffold(
      backgroundColor: AppColors.tvDarkBg,
      appBar: AppBar(
        backgroundColor: AppColors.tvDarkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      instrument.symbol,
                      style: AppTypography.headlineSm.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.tvCardBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.tvBorder),
                      ),
                      child: Text(
                        instrument.exchange,
                        style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.outline),
                      ),
                    ),
                  ],
                ),
                Text(
                  instrument.name,
                  style: AppTypography.bodyMd.copyWith(fontSize: 11, color: AppColors.outline),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
        actions: [
          InkWell(
            onTap: () => _showTradingViewModal(context, instrument),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.kiteGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.kiteGreen.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.kiteGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'TRADINGVIEW PRO ↗',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.kiteGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Live Price & Quick Status Banner (Zerodha Kite Style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.tvCardBg,
                border: Border(bottom: BorderSide(color: AppColors.tvBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Text(
                          '$currency${ltp.toStringAsFixed(2)}',
                          style: AppTypography.numericTicker.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isPos ? AppColors.kiteGreen : AppColors.kiteRed,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isPos ? AppColors.kiteGreen : AppColors.kiteRed).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${isPos ? '+' : ''}${change.toStringAsFixed(2)} (${changePct.toStringAsFixed(2)}%)',
                          style: AppTypography.numericTable.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isPos ? AppColors.kiteGreen : AppColors.kiteRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Timeframe: ',
                        style: AppTypography.labelSm.copyWith(fontSize: 10, color: AppColors.outline),
                      ),
                      Text(
                        interval.toUpperCase(),
                        style: AppTypography.labelSm.copyWith(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.zerodhaBlue),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Live P&L Position Ribbon (If holding exists)
            if (hasHolding)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: holdingIsPos
                        ? [AppColors.kiteGreen.withOpacity(0.15), AppColors.tvCardBg]
                        : [AppColors.kiteRed.withOpacity(0.15), AppColors.tvCardBg],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (holdingIsPos ? AppColors.kiteGreen : AppColors.kiteRed).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.flash_on, size: 14, color: AppColors.warning),
                            const SizedBox(width: 4),
                            Text(
                              'OPEN POSITION: ${activeHolding.quantity} LOTS',
                              style: AppTypography.labelSm.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Avg Entry: $currency${activeHolding.averageBuyPrice.toStringAsFixed(2)}',
                          style: AppTypography.bodyMd.copyWith(fontSize: 11, color: AppColors.outline),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'LIVE P&L',
                          style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.outline),
                        ),
                        const SizedBox(height: 1),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: holdingPnl, end: holdingPnl),
                          duration: const Duration(milliseconds: 300),
                          builder: (context, val, _) {
                            return Text(
                              '${val >= 0 ? '+' : ''}$currency${val.toStringAsFixed(2)} (${holdingPnlPct.toStringAsFixed(2)}%)',
                              style: AppTypography.numericTable.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: val >= 0 ? AppColors.kiteGreen : AppColors.kiteRed,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Candlestick Chart View
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: CandlestickChartView(
                  symbol: instrument.symbol,
                  candles: candlesAsync.valueOrNull ?? [],
                  currentPrice: ltp,
                  currencySymbol: currency,
                  isLoading: candlesAsync.isLoading,
                  errorMessage: candlesAsync.hasError ? candlesAsync.error.toString() : null,
                  selectedInterval: interval,
                  onIntervalChanged: (newInterval) {
                    ref.read(selectedCandleIntervalProvider.notifier).state = newInterval;
                  },
                  selectedRange: range,
                  onRangeChanged: (newRange) {
                    ref.read(selectedHistoryRangeProvider.notifier).state = newRange;
                  },
                  status: liveQuote?.status == 'LIVE'
                      ? 'LIVE'
                      : (instrument.isSimulated ? 'SIMULATED' : 'DELAYED'),
                  onRetry: () => ref.refresh(candlesProvider(CandleQuery(symbol: instrument.symbol, interval: interval, range: range))),
                  onOpenTradingView: () => _showTradingViewModal(context, instrument),
                ),
              ),
            ),

            // Quick Execution Action Bar (Zerodha / Upstox Pro Dock)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.tvCardBg,
                border: Border(top: BorderSide(color: AppColors.tvBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kiteGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        onPressed: () => _openQuickOrderModal(context, instrument, ltp, true),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.arrow_upward, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'BUY $currency${ltp.toStringAsFixed(2)}',
                              style: AppTypography.headlineSm.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kiteRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        onPressed: () => _openQuickOrderModal(context, instrument, ltp, false),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.arrow_downward, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'SELL $currency${ltp.toStringAsFixed(2)}',
                              style: AppTypography.headlineSm.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickOrderSheet extends ConsumerStatefulWidget {
  final InstrumentModel instrument;
  final double currentLtp;
  final bool initialIsBuy;

  const _QuickOrderSheet({
    required this.instrument,
    required this.currentLtp,
    required this.initialIsBuy,
  });

  @override
  ConsumerState<_QuickOrderSheet> createState() => _QuickOrderSheetState();
}

class _QuickOrderSheetState extends ConsumerState<_QuickOrderSheet> {
  late bool _isBuy;
  int _quantity = 10;
  String _product = 'MIS'; // MIS (Intraday 5x) or CNC (Delivery 1x)
  bool _isSubmitting = false;

  double get _liveLtp {
    final quote = ref.read(liveQuoteForSymbolProvider(widget.instrument.symbol));
    return quote != null && quote.price > 0 ? quote.price : widget.currentLtp;
  }

  @override
  void initState() {
    super.initState();
    _isBuy = widget.initialIsBuy;
  }

  double _getRequiredMargin() {
    final raw = _quantity * _liveLtp;
    return _product == 'MIS' ? raw / 5.0 : raw;
  }

  Future<void> _submitOrder() async {
    setState(() => _isSubmitting = true);
    final portfolio = ref.read(portfolioProvider).valueOrNull;
    final availableCash = portfolio?.availableCash ?? 1000000.0;
    final requiredMargin = _getRequiredMargin();

    if (requiredMargin > availableCash) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.errorContainer,
            content: Text(
              'Insufficient virtual margin: Need ₹${requiredMargin.toStringAsFixed(2)}, Available ₹${availableCash.toStringAsFixed(2)}',
            ),
          ),
        );
      }
      return;
    }

    try {
      final result = await ref.read(submitOrderProvider).submitOrder(
        symbol: widget.instrument.symbol,
        exchange: widget.instrument.exchange,
        side: _isBuy ? 'BUY' : 'SELL',
        orderType: 'MARKET',
        product: _product,
        quantity: _quantity,
      );
      if (result['success'] != true) {
        throw StateError(result['message'] as String? ?? 'Order execution failed.');
      }
      final execution = result['execution'];
      final order = result['order'];
      final bookedPrice = execution is Map<String, dynamic>
          ? (execution['executionPrice'] as num?)?.toDouble()
          : (order is Map<String, dynamic>
              ? (order['averagePrice'] as num?)?.toDouble()
              : null);

      final isCrypto = widget.instrument.symbol.contains('/') || ['BTC', 'ETH', 'SOL'].any((c) => widget.instrument.symbol.contains(c));
      final currency = (isCrypto || widget.instrument.exchange == 'US' || widget.instrument.category == 'US') ? '\$' : '₹';

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceContainer,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _isBuy ? AppColors.kiteGreen : AppColors.kiteRed, width: 1.5),
          ),
          content: Row(
            children: [
              Icon(Icons.check_circle, color: _isBuy ? AppColors.kiteGreen : AppColors.kiteRed, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Booked Successfully! 🎉',
                      style: AppTypography.bodyLg.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isBuy ? AppColors.kiteGreen : AppColors.kiteRed,
                      ),
                    ),
                    Text(
                      '${_isBuy ? 'BOUGHT' : 'SOLD'} $_quantity ${widget.instrument.symbol} @ $currency${(bookedPrice ?? _liveLtp).toStringAsFixed(2)} ($_product)',
                      style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.errorContainer, content: Text('Order failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(liveQuoteForSymbolProvider(widget.instrument.symbol));
    final isCrypto = widget.instrument.symbol.contains('/') || ['BTC', 'ETH', 'SOL'].any((c) => widget.instrument.symbol.contains(c));
    final currency = (isCrypto || widget.instrument.exchange == 'US' || widget.instrument.category == 'US') ? '\$' : '₹';
    final margin = _getRequiredMargin();
    final portfolio = ref.watch(portfolioProvider).valueOrNull;
    final available = portfolio?.availableCash ?? 1000000.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    widget.instrument.symbol,
                    style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.tvCardBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(widget.instrument.exchange, style: AppTypography.labelSm.copyWith(fontSize: 10)),
                  ),
                ],
              ),
              Text(
                '$currency${_liveLtp.toStringAsFixed(2)}',
                style: AppTypography.numericTicker.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Buy / Sell Switcher
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isBuy = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isBuy ? AppColors.kiteGreen.withOpacity(0.2) : AppColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _isBuy ? AppColors.kiteGreen : AppColors.borderSubtle),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'BUY (LONG)',
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isBuy ? AppColors.kiteGreen : AppColors.outline,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isBuy = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_isBuy ? AppColors.kiteRed.withOpacity(0.2) : AppColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: !_isBuy ? AppColors.kiteRed : AppColors.borderSubtle),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'SELL (SHORT)',
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.bold,
                        color: !_isBuy ? AppColors.kiteRed : AppColors.outline,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Product Type: MIS vs CNC
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Intraday (MIS 5x)'),
                  selected: _product == 'MIS',
                  selectedColor: AppColors.zerodhaBlue.withOpacity(0.25),
                  onSelected: (val) => setState(() => _product = 'MIS'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Delivery (CNC 1x)'),
                  selected: _product == 'CNC',
                  selectedColor: AppColors.zerodhaBlue.withOpacity(0.25),
                  onSelected: (val) => setState(() => _product = 'CNC'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Quantity Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quantity (Lots)', style: AppTypography.labelMd),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.onSurface),
                    onPressed: () {
                      if (_quantity > 1) setState(() => _quantity -= 1);
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text('$_quantity', style: AppTypography.numericTicker.copyWith(fontSize: 16)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.onSurface),
                    onPressed: () => setState(() => _quantity += 1),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Margin Info Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Required Margin:', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                    Text(
                      '$currency${margin.toStringAsFixed(2)}',
                      style: AppTypography.numericTable.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Available Margin:', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                    Text('$currency${available.toStringAsFixed(2)}', style: AppTypography.numericTable),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Brokerage & Charges:', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                    Text('$currency 20.00', style: AppTypography.numericTable),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Confirm Execution Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isBuy ? AppColors.kiteGreen : AppColors.kiteRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSubmitting ? null : _submitOrder,
              child: _isSubmitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      _isBuy ? 'Confirm BUY Order' : 'Confirm SELL Order',
                      style: AppTypography.headlineSm.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
