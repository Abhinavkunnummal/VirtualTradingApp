import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/network/live_ticker_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../markets/domain/market_models.dart';
import '../../portfolio/domain/portfolio_models.dart';
import '../../portfolio/presentation/providers/portfolio_provider.dart';
import 'providers/order_provider.dart';
import 'widgets/candlestick_chart_view.dart';

class TradingViewChartScreen extends ConsumerStatefulWidget {
  final InstrumentModel? instrument;

  const TradingViewChartScreen({super.key, this.instrument});

  @override
  ConsumerState<TradingViewChartScreen> createState() => _TradingViewChartScreenState();
}

class _TradingViewChartScreenState extends ConsumerState<TradingViewChartScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  double? _lastLtp;

  WebViewController? _webViewController;
  bool _isWebViewReady = false;
  bool _hasWebViewError = false;
  bool _isDelayed = false;
  String _selectedChartType = 'candles'; // 'candles', 'line', 'area', 'bars'

  static const List<String> _supportedIntervals = ['1m', '5m', '15m', '1h', '1d'];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final bool isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      _initWebViewController();
    } else {
      _hasWebViewError = true; // Use canvas chart in widget tests
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final instrument = _getEffectiveInstrument();
      final interval = ref.read(selectedCandleIntervalProvider);

      ref.read(liveQuotesProvider.notifier).trackSymbol(instrument.symbol);
      ref.read(liveQuotesProvider.notifier).subscribeChart(
        symbol: instrument.symbol,
        interval: interval,
        onReconnect: _onSocketReconnect,
      );
      ref.read(liveQuotesProvider.notifier).addChartTickListener(_onChartTick);
    });
  }

  @override
  void dispose() {
    final instrument = _getEffectiveInstrument();
    final interval = ref.read(selectedCandleIntervalProvider);
    ref.read(liveQuotesProvider.notifier).removeChartTickListener(_onChartTick);
    ref.read(liveQuotesProvider.notifier).unsubscribeChart(
      symbol: instrument.symbol,
      interval: interval,
    );
    _pulseController.dispose();
    super.dispose();
  }

  InstrumentModel _getEffectiveInstrument() {
    return widget.instrument ?? ref.read(selectedTradeInstrumentProvider);
  }

  void _initWebViewController() {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(AppColors.tvDarkBg)
        ..addJavaScriptChannel(
          'Flutter',
          onMessageReceived: (JavaScriptMessage msg) {
            _handleJavaScriptMessage(msg.message);
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (!mounted) return;
              _isWebViewReady = true;
              _syncCandlesToWebView();
              _syncPositionLinesToWebView();
            },
            onWebResourceError: (_) {
              if (mounted) {
                setState(() => _hasWebViewError = true);
              }
            },
          ),
        )
        ..loadFlutterAsset('assets/chart/chart.html');

      _webViewController = controller;
    } catch (_) {
      _hasWebViewError = true;
    }
  }

  void _handleJavaScriptMessage(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type == 'onChartReady') {
        _isWebViewReady = true;
        _syncCandlesToWebView();
        _syncPositionLinesToWebView();
      }
    } catch (_) {}
  }

  void _onSocketReconnect() {
    if (!mounted) return;
    final instrument = _getEffectiveInstrument();
    final interval = ref.read(selectedCandleIntervalProvider);
    final range = ref.read(selectedHistoryRangeProvider);

    // Re-fetch latest candles after network reconnect
    ref.invalidate(candlesProvider(CandleQuery(
      symbol: instrument.symbol,
      interval: interval,
      range: range,
    )));
  }

  void _onChartTick(Map<String, dynamic> data) {
    if (!mounted) return;
    final instrument = _getEffectiveInstrument();
    final tickSymbol = data['symbol'] as String?;

    if (tickSymbol != null && !_isMatchingSymbol(tickSymbol, instrument.symbol)) {
      return;
    }

    final delayed = data['delayed'] == true;
    if (_isDelayed != delayed) {
      setState(() => _isDelayed = delayed);
      _webViewController?.runJavaScript('window.setDelayedBadge($delayed);');
    }

    final jsonStr = jsonEncode(data);
    _webViewController?.runJavaScript('window.updateCandle($jsonStr);');

    final close = (data['close'] as num?)?.toDouble();
    if (close != null && close > 0) {
      _triggerPricePulse(close);
    }
  }

  bool _isMatchingSymbol(String a, String b) {
    final cleanA = a.toUpperCase().replaceAll(RegExp(r'[\/\-_]'), '').replaceFirst(RegExp(r'USDT$|USD$'), '');
    final cleanB = b.toUpperCase().replaceAll(RegExp(r'[\/\-_]'), '').replaceFirst(RegExp(r'USDT$|USD$'), '');
    return cleanA == cleanB;
  }

  void _syncCandlesToWebView() {
    if (!_isWebViewReady || _webViewController == null) return;
    final instrument = _getEffectiveInstrument();
    final interval = ref.read(selectedCandleIntervalProvider);
    final range = ref.read(selectedHistoryRangeProvider);

    final candles = ref.read(candlesProvider(CandleQuery(
      symbol: instrument.symbol,
      interval: interval,
      range: range,
    ))).valueOrNull;

    if (candles != null && candles.isNotEmpty) {
      final candlesJson = jsonEncode(candles.map((c) => c.toJson()).toList());
      _webViewController!.runJavaScript(
        'window.setCandles($candlesJson); window.setSymbol("${instrument.symbol}"); window.setDelayedBadge($_isDelayed);',
      );
    }
  }

  void _syncPositionLinesToWebView() {
    if (!_isWebViewReady || _webViewController == null) return;
    final instrument = _getEffectiveInstrument();
    final portfolio = ref.read(portfolioProvider).valueOrNull;
    final isCrypto = instrument.symbol.contains('/') || ['BTC', 'ETH', 'SOL'].any((c) => instrument.symbol.contains(c));
    final currency = (isCrypto || instrument.exchange == 'US') ? '\$' : '₹';

    final activeHolding = portfolio?.holdings
        .where((h) => _isMatchingSymbol(h.symbol, instrument.symbol))
        .firstOrNull;

    if (activeHolding != null && activeHolding.quantity > 0) {
      final posData = {
        'entryPrice': activeHolding.averageBuyPrice,
        'quantity': activeHolding.quantity,
        'isBuy': true,
        'currency': currency,
        'slPrice': activeHolding.averageBuyPrice * 0.98,
        'targetPrice': activeHolding.averageBuyPrice * 1.04,
      };
      _webViewController!.runJavaScript('window.setPositionLines(${jsonEncode(posData)});');
    } else {
      _webViewController!.runJavaScript('window.clearPositionLines();');
    }
  }

  void _changeInterval(String newInterval) {
    final instrument = _getEffectiveInstrument();
    final oldInterval = ref.read(selectedCandleIntervalProvider);
    if (oldInterval == newInterval) return;

    ref.read(liveQuotesProvider.notifier).unsubscribeChart(
      symbol: instrument.symbol,
      interval: oldInterval,
    );

    ref.read(selectedCandleIntervalProvider.notifier).state = newInterval;

    ref.read(liveQuotesProvider.notifier).subscribeChart(
      symbol: instrument.symbol,
      interval: newInterval,
      onReconnect: _onSocketReconnect,
    );

    // Refresh history
    ref.invalidate(candlesProvider(CandleQuery(
      symbol: instrument.symbol,
      interval: newInterval,
      range: ref.read(selectedHistoryRangeProvider),
    )));
  }

  void _changeChartType(String type) {
    setState(() => _selectedChartType = type);
    _webViewController?.runJavaScript('window.setChartType("$type");');
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

  @override
  Widget build(BuildContext context) {
    final instrument = widget.instrument ?? ref.watch(selectedTradeInstrumentProvider);
    final interval = ref.watch(selectedCandleIntervalProvider);
    final range = ref.watch(selectedHistoryRangeProvider);
    final portfolio = ref.watch(portfolioProvider).valueOrNull;

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

    // When candles finish loading, sync to webview
    candlesAsync.whenData((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncCandlesToWebView();
        _syncPositionLinesToWebView();
      });
    });

    // Active position lookup for this stock
    final activeHolding = portfolio?.holdings
        .where((h) => _isMatchingSymbol(h.symbol, instrument.symbol))
        .firstOrNull;
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
                    if (_isDelayed) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.kiteRed.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.kiteRed.withOpacity(0.4)),
                        ),
                        child: Text(
                          'DELAYED',
                          style: AppTypography.labelSm.copyWith(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.kiteRed),
                        ),
                      ),
                    ],
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
          IconButton(
            tooltip: _hasWebViewError ? 'Switch to Lightweight Chart' : 'Switch to Canvas Chart',
            icon: Icon(
              _hasWebViewError ? Icons.web : Icons.brush,
              size: 20,
              color: AppColors.outline,
            ),
            onPressed: () {
              setState(() => _hasWebViewError = !_hasWebViewError);
            },
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
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.zerodhaBlue,
                        ),
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

            // Timeframe & Chart-Type Pro Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: const BoxDecoration(
                color: AppColors.tvCardBg,
                border: Border(bottom: BorderSide(color: AppColors.tvBorder)),
              ),
              child: Row(
                children: [
                  // Interval selection pills
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _supportedIntervals.map((i) {
                          final isSelected = i.toLowerCase() == interval.toLowerCase();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => _changeInterval(i),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.zerodhaBlue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected ? AppColors.zerodhaBlue : AppColors.tvBorder,
                                  ),
                                ),
                                child: Text(
                                  i.toUpperCase(),
                                  style: AppTypography.labelSm.copyWith(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? Colors.white : AppColors.outline,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // Chart type toggle
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.tvDarkBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.tvBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildChartTypeIcon('candles', Icons.candlestick_chart, 'Candles'),
                        _buildChartTypeIcon('line', Icons.show_chart, 'Line'),
                        _buildChartTypeIcon('area', Icons.area_chart, 'Area'),
                        _buildChartTypeIcon('bars', Icons.view_column_outlined, 'Bars'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Chart View: TradingView Lightweight Charts (or Fallback Canvas)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: _hasWebViewError
                    ? CandlestickChartView(
                        symbol: instrument.symbol,
                        candles: candlesAsync.valueOrNull ?? [],
                        currentPrice: ltp,
                        currencySymbol: currency,
                        isLoading: candlesAsync.isLoading,
                        errorMessage: candlesAsync.hasError ? candlesAsync.error.toString() : null,
                        selectedInterval: interval,
                        onIntervalChanged: _changeInterval,
                        selectedRange: range,
                        onRangeChanged: (newRange) {
                          ref.read(selectedHistoryRangeProvider.notifier).state = newRange;
                        },
                        status: _isDelayed ? 'DELAYED' : (liveQuote?.status == 'LIVE' ? 'LIVE' : 'SIMULATED'),
                        onRetry: () => ref.refresh(candlesProvider(CandleQuery(
                          symbol: instrument.symbol,
                          interval: interval,
                          range: range,
                        ))),
                      )
                    : Stack(
                        children: [
                          if (_webViewController != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: WebViewWidget(controller: _webViewController!),
                            ),
                          if (candlesAsync.isLoading)
                            const Center(
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.zerodhaBlue),
                            ),
                        ],
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

  Widget _buildChartTypeIcon(String type, IconData icon, String tooltip) {
    final isSelected = _selectedChartType == type;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => _changeChartType(type),
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.tvCardBg : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? AppColors.zerodhaBlue : AppColors.outline,
          ),
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
                      '${_isBuy ? 'BUY' : 'SELL'} Booked Successfully!',
                      style: AppTypography.headlineSm.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _isBuy ? AppColors.kiteGreen : AppColors.kiteRed,
                      ),
                    ),
                    Text(
                      '${widget.instrument.symbol} • $_quantity Lots @ $currency${(bookedPrice ?? _liveLtp).toStringAsFixed(2)}',
                      style: AppTypography.bodyMd.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.errorContainer,
          content: Text(
            e is StateError ? e.message : 'Order execution failed. Please check balance and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final livePrice = _liveLtp;
    final isCrypto = widget.instrument.symbol.contains('/') || ['BTC', 'ETH', 'SOL'].any((c) => widget.instrument.symbol.contains(c));
    final currency = (isCrypto || widget.instrument.exchange == 'US' || widget.instrument.category == 'US') ? '\$' : '₹';

    final portfolio = ref.watch(portfolioProvider).valueOrNull;
    final available = portfolio?.availableCash ?? 1000000.0;
    final margin = _getRequiredMargin();

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
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.instrument.symbol,
                    style: AppTypography.headlineSm.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${widget.instrument.exchange} • ${widget.instrument.name}',
                    style: AppTypography.bodyMd.copyWith(fontSize: 12, color: AppColors.outline),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currency${livePrice.toStringAsFixed(2)}',
                    style: AppTypography.numericTicker.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isBuy ? AppColors.kiteGreen : AppColors.kiteRed,
                    ),
                  ),
                  Text(
                    'REAL-TIME PRICE',
                    style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.outline),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Buy / Sell Selector Pill
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _isBuy = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isBuy ? AppColors.kiteGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'BUY',
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _isBuy ? Colors.white : AppColors.outline,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _isBuy = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isBuy ? AppColors.kiteRed : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'SELL',
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.bold,
                          color: !_isBuy ? Colors.white : AppColors.outline,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Product Type: Intraday MIS (5x) vs CNC/Delivery (1x)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _product = 'MIS'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _product == 'MIS' ? AppColors.zerodhaBlue.withOpacity(0.15) : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _product == 'MIS' ? AppColors.zerodhaBlue : Colors.transparent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Text('INTRADAY (MIS)', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                        Text('5x Leverage', style: AppTypography.labelSm.copyWith(fontSize: 10, color: AppColors.zerodhaBlue)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _product = 'CNC'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _product == 'CNC' ? AppColors.zerodhaBlue.withOpacity(0.15) : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _product == 'CNC' ? AppColors.zerodhaBlue : Colors.transparent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Text('DELIVERY (CNC)', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                        Text('1x Margin', style: AppTypography.labelSm.copyWith(fontSize: 10, color: AppColors.outline)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quantity Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quantity (Lots):', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.outline),
                    onPressed: _quantity > 1 ? () => setState(() => _quantity -= 1) : null,
                  ),
                  Container(
                    width: 50,
                    alignment: Alignment.center,
                    child: Text(
                      '$_quantity',
                      style: AppTypography.headlineSm.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    onPressed: () => setState(() => _quantity += 1),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Margin Required vs Available Info Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outlineVariant),
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
