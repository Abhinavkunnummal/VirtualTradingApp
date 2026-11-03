import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/loading_state_widget.dart';
import '../../../../shared/widgets/error_state_widget.dart';
import 'chart_indicators.dart';

class CandleData {
  final int timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const CandleData({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  bool get isBullish => close >= open;

  CandleData copyWith({
    int? timestamp,
    double? open,
    double? high,
    double? low,
    double? close,
    double? volume,
  }) {
    return CandleData(
      timestamp: timestamp ?? this.timestamp,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
    );
  }

  factory CandleData.fromJson(Map<String, dynamic> json) {
    return CandleData(
      timestamp: (json['time'] as num?)?.toInt() ?? (json['timestamp'] as num?)?.toInt() ?? 0,
      open: (json['open'] as num?)?.toDouble() ?? 0.0,
      high: (json['high'] as num?)?.toDouble() ?? 0.0,
      low: (json['low'] as num?)?.toDouble() ?? 0.0,
      close: (json['close'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'time': timestamp,
    'open': open,
    'high': high,
    'low': low,
    'close': close,
    'volume': volume,
  };
}

class CandlestickChartView extends StatefulWidget {
  final String symbol;
  final List<CandleData> candles;
  final double? currentPrice;
  final String? currencySymbol;
  final bool isLoading;
  final String? errorMessage;
  final String selectedInterval;
  final ValueChanged<String> onIntervalChanged;
  final String selectedRange;
  final ValueChanged<String>? onRangeChanged;
  final String status;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenTradingView;

  const CandlestickChartView({
    super.key,
    required this.symbol,
    required this.candles,
    this.currentPrice,
    this.currencySymbol,
    this.isLoading = false,
    this.errorMessage,
    required this.selectedInterval,
    required this.onIntervalChanged,
    this.selectedRange = '1D',
    this.onRangeChanged,
    this.status = 'SIMULATED',
    this.onRetry,
    this.onOpenTradingView,
  });

  static double calculateCandleWidth(double chartWidth, int candleCount, double zoom) {
    if (candleCount <= 0 || chartWidth <= 0) return 8.0;
    final visibleCount = candleCount > 32 ? 32.0 : math.max(candleCount.toDouble(), 12.0);
    final baseWidth = (chartWidth / visibleCount).clamp(6.5, 20.0);
    return baseWidth * zoom;
  }

  @override
  State<CandlestickChartView> createState() => _CandlestickChartViewState();
}

class _CandlestickChartViewState extends State<CandlestickChartView> {
  CandleData? _inspectedCandle;

  // Technical indicator visibility toggles
  bool _showSma20 = false;
  // Keep a trend line visible by default; traders can still toggle it off.
  bool _showEma20 = true;
  bool _showRsi = false;
  bool _showMacd = false;

  // Pan and Zoom
  double _panOffset = 0.0;
  double _zoomScale = 1.0;
  double _baseZoomScale = 1.0;
  bool _needsPanReset = true;

  // Cached indicator data
  List<double?> _sma20 = [];
  List<double?> _ema20 = [];
  List<double?> _rsi14 = [];
  Map<String, List<double?>> _macd = {};

  void _resetPan(double maxWidth) {
    if (widget.candles.isEmpty || maxWidth <= 0) {
      _panOffset = 0.0;
      return;
    }
    const axisWidth = 54.0;
    final chartWidth = math.max(maxWidth - axisWidth, 50.0);
    final candleWidth = CandlestickChartView.calculateCandleWidth(chartWidth, widget.candles.length, _zoomScale);
    final totalWidth = widget.candles.length * candleWidth;
    if (totalWidth > chartWidth) {
      _panOffset = chartWidth - totalWidth - 10.0;
    } else {
      _panOffset = 0.0;
    }
  }

  @override
  void initState() {
    super.initState();
    _recalculateIndicators();
    _needsPanReset = true;
  }

  @override
  void didUpdateWidget(covariant CandlestickChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.selectedInterval != widget.selectedInterval ||
        oldWidget.selectedRange != widget.selectedRange ||
        oldWidget.candles.length != widget.candles.length) {
      _inspectedCandle = null;
      _needsPanReset = true;
      _recalculateIndicators();
    }
  }

  void _recalculateIndicators() {
    if (widget.candles.isEmpty) {
      _sma20 = [];
      _ema20 = [];
      _rsi14 = [];
      _macd = {};
      return;
    }
    _sma20 = ChartIndicatorCalculator.calculateSMA(widget.candles, 20);
    _ema20 = ChartIndicatorCalculator.calculateEMA(widget.candles, 20);
    _rsi14 = ChartIndicatorCalculator.calculateRSI(widget.candles, 14);
    _macd = ChartIndicatorCalculator.calculateMACD(widget.candles, 12, 26, 9);
  }

  @override
  Widget build(BuildContext context) {
    final List<CandleData> effectiveCandles = List<CandleData>.from(widget.candles);
    if (widget.currentPrice != null && effectiveCandles.isNotEmpty) {
      final lastCandle = effectiveCandles.last;
      final livePrice = widget.currentPrice!;
      effectiveCandles[effectiveCandles.length - 1] = lastCandle.copyWith(
        close: livePrice,
        high: math.max(lastCandle.high, livePrice),
        low: math.min(lastCandle.low, livePrice),
      );
    }
    final activeCandle = _inspectedCandle ?? (effectiveCandles.isNotEmpty ? effectiveCandles.last : null);
    final displayPrice = activeCandle?.close ?? widget.currentPrice;
    final currency = widget.currencySymbol ??
        (widget.symbol.contains('/') ||
                widget.symbol == 'BTC/USDT' ||
                widget.symbol == 'ETH/USDT' ||
                widget.symbol == 'NVDA' ||
                widget.symbol == 'AAPL'
            ? '\$'
            : '₹');

    // Dynamic height based on active indicator oscillator sub-panels
    double chartHeight = 210.0;
    if (_showRsi) chartHeight += 55.0;
    if (_showMacd) chartHeight += 55.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header with Stock Symbol, Status Pill, Range & Interval Readout, and LTP
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      widget.symbol,
                      style: AppTypography.headlineSm.copyWith(fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.status == 'LIVE'
                            ? AppColors.secondary.withOpacity(0.15)
                            : AppColors.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: widget.status == 'LIVE'
                              ? AppColors.secondary.withOpacity(0.3)
                              : AppColors.warning.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '${widget.status} • ${widget.selectedInterval.toUpperCase()}',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 9,
                          color: widget.status == 'LIVE' ? AppColors.secondary : AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (displayPrice != null)
                  Text(
                    '$currency${displayPrice.toStringAsFixed(2)}',
                    style: AppTypography.numericTable.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: (activeCandle?.isBullish ?? true) ? AppColors.secondary : AppColors.tertiary,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 6),

          // 2. Crosshair Inspection / Active Candle OHLCV Readout
          if (activeCandle != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildOhlcItem('O', activeCandle.open),
                        const SizedBox(width: 6),
                        _buildOhlcItem('H', activeCandle.high),
                        const SizedBox(width: 6),
                        _buildOhlcItem('L', activeCandle.low),
                        const SizedBox(width: 6),
                        _buildOhlcItem('C', activeCandle.close, isClose: true, isBull: activeCandle.isBullish),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: activeCandle.isBullish ? AppColors.secondary.withOpacity(0.15) : AppColors.tertiary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: activeCandle.isBullish ? AppColors.secondary.withOpacity(0.35) : AppColors.tertiary.withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        activeCandle.isBullish ? Icons.trending_up : Icons.trending_down,
                        size: 11,
                        color: activeCandle.isBullish ? AppColors.secondary : AppColors.tertiary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        activeCandle.isBullish ? 'UPTREND' : 'DOWNTREND',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: activeCandle.isBullish ? AppColors.secondary : AppColors.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),

          // 3. Technical Indicator Toggles Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildIndicatorChip('SMA(20)', _showSma20, const Color(0xFFFFB300), () {
                  setState(() => _showSma20 = !_showSma20);
                }),
                const SizedBox(width: 6),
                _buildIndicatorChip('EMA(20)', _showEma20, const Color(0xFF00E5FF), () {
                  setState(() => _showEma20 = !_showEma20);
                }),
                const SizedBox(width: 6),
                _buildIndicatorChip('RSI(14)', _showRsi, const Color(0xFFAB47BC), () {
                  setState(() => _showRsi = !_showRsi);
                }),
                const SizedBox(width: 6),
                _buildIndicatorChip('MACD', _showMacd, const Color(0xFF29B6F6), () {
                  setState(() => _showMacd = !_showMacd);
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 4. Interactive Chart Canvas with Pan, Zoom, and Touch Inspection
          SizedBox(
            height: chartHeight,
            child: widget.isLoading
                ? LoadingStateWidget(message: 'Loading ${widget.symbol} (${widget.selectedInterval}) candles...')
                : widget.errorMessage != null
                    ? ErrorStateWidget(
                        title: 'Chart Unavailable',
                        message: widget.errorMessage!,
                        onRetry: widget.onRetry,
                      )
                    : widget.candles.isEmpty
                        ? Center(
                            child: Text(
                              'No ${widget.selectedInterval} historical ticks for ${widget.symbol}.',
                              style: AppTypography.bodyMd,
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              if (_needsPanReset && widget.candles.isNotEmpty) {
                                _resetPan(constraints.maxWidth);
                                _needsPanReset = false;
                              }
                              const axisWidth = 54.0;
                              final chartWidth = math.max(constraints.maxWidth - axisWidth, 50.0);
                              final candleWidth = CandlestickChartView.calculateCandleWidth(chartWidth, widget.candles.length, _zoomScale);

                              return GestureDetector(
                                onScaleStart: (details) {
                                  _baseZoomScale = _zoomScale;
                                },
                                onScaleUpdate: (details) {
                                  setState(() {
                                    if (details.scale != 1.0) {
                                      _zoomScale = (_baseZoomScale * details.scale).clamp(0.5, 3.5);
                                    }
                                    _panOffset += details.focalPointDelta.dx;
                                    final totalWidth = widget.candles.length * candleWidth;
                                    if (totalWidth > chartWidth) {
                                      final minPan = chartWidth - totalWidth - 30.0;
                                      const maxPan = 30.0;
                                      _panOffset = _panOffset.clamp(minPan, maxPan);
                                    } else {
                                      _panOffset = 0.0;
                                    }
                                    _handleInspect(details.localFocalPoint.dx, constraints.maxWidth);
                                  });
                                },
                                onTapDown: (details) {
                                  _handleInspect(details.localPosition.dx, constraints.maxWidth);
                                },
                                onDoubleTap: () {
                                  setState(() {
                                    _inspectedCandle = null;
                                    _zoomScale = 1.0;
                                    _resetPan(constraints.maxWidth);
                                  });
                                },
                                onLongPressEnd: (_) {
                                  setState(() => _inspectedCandle = null);
                                },
                                child: CustomPaint(
                                  size: Size(constraints.maxWidth, chartHeight),
                                  painter: _CandlestickPainter(
                                    candles: effectiveCandles,
                                    inspectedCandle: _inspectedCandle,
                                    currentPrice: widget.currentPrice,
                                    currencySymbol: currency,
                                    selectedInterval: widget.selectedInterval,
                                    showSma20: _showSma20,
                                    showEma20: _showEma20,
                                    showRsi: _showRsi,
                                    showMacd: _showMacd,
                                    sma20: _sma20,
                                    ema20: _ema20,
                                    rsi14: _rsi14,
                                    macd: _macd,
                                    panOffset: _panOffset,
                                    zoomScale: _zoomScale,
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          const SizedBox(height: 8),

          // 5. Timeframe / Interval Selector Chips (1m, 5m, 15m, 30m, 1h, 4h, 1d, 1w, 1M)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('INTERVAL', style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.outline)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                  children: ['1m', '5m', '15m', '30m', '1h', '4h', '1d', '1w', '1M'].map((interval) {
                    final isSelected = widget.selectedInterval.toLowerCase() == interval.toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        key: ValueKey('interval_$interval'),
                        onTap: () => widget.onIntervalChanged(interval),
                        borderRadius: BorderRadius.circular(5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryBrand.withOpacity(0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryBrand : AppColors.borderSubtle,
                            ),
                          ),
                          child: Text(
                            interval.toUpperCase(),
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 9,
                              color: isSelected ? AppColors.primary : AppColors.outline,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

          // 6. 5-Year History Range Selector Chips (1D, 1W, 1M, 3M, 6M, 1Y, 3Y, 5Y, ALL)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RANGE', style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.outline)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                    ...['1D', '1W', '1M', '3M', '6M', '1Y', '3Y', '5Y', 'ALL'].map((range) {
                      final isSelected = widget.selectedRange.toUpperCase() == range.toUpperCase();
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: InkWell(
                          key: ValueKey('range_$range'),
                          onTap: widget.onRangeChanged != null ? () => widget.onRangeChanged!(range) : null,
                          borderRadius: BorderRadius.circular(5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.secondary.withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isSelected ? AppColors.secondary : AppColors.borderSubtle,
                              ),
                            ),
                            child: Text(
                              range,
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 9,
                                color: isSelected ? AppColors.secondary : AppColors.outline,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    if (widget.onOpenTradingView != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: InkWell(
                          key: const ValueKey('open_tradingview_pro_chip'),
                          onTap: widget.onOpenTradingView,
                          borderRadius: BorderRadius.circular(5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.zerodhaBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: AppColors.zerodhaBlue),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.show_chart, size: 12, color: AppColors.zerodhaBlue),
                                const SizedBox(width: 4),
                                Text(
                                  'TRADINGVIEW CHART ↗',
                                  style: AppTypography.labelSm.copyWith(
                                    fontSize: 9,
                                    color: AppColors.zerodhaBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ),
);
  }

  Widget _buildIndicatorChip(String label, bool active, Color color, VoidCallback onTap) {
    return InkWell(
      key: ValueKey('indicator_$label'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.18) : AppColors.surfaceLowest,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: active ? color : AppColors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: active ? color : AppColors.outline),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                fontSize: 9,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? color : AppColors.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleInspect(double touchX, double width) {
    if (widget.candles.isEmpty || width <= 0) return;
    const axisWidth = 54.0;
    final chartWidth = math.max(width - axisWidth, 50.0);
    final candleWidth = CandlestickChartView.calculateCandleWidth(chartWidth, widget.candles.length, _zoomScale);
    if (candleWidth <= 0) return;

    final adjustedX = touchX - _panOffset;
    final index = (adjustedX / candleWidth).clamp(0, widget.candles.length - 1).toInt();
    final candle = widget.candles[index];
    if (index == widget.candles.length - 1 && widget.currentPrice != null) {
      final livePrice = widget.currentPrice!;
      setState(() {
        _inspectedCandle = candle.copyWith(
          close: livePrice,
          high: math.max(candle.high, livePrice),
          low: math.min(candle.low, livePrice),
        );
      });
    } else {
      setState(() {
        _inspectedCandle = candle;
      });
    }
  }

  Widget _buildOhlcItem(String label, double value, {bool isClose = false, bool isBull = true}) {
    Color valColor = AppColors.onSurface;
    if (isClose) {
      valColor = isBull ? AppColors.secondary : AppColors.tertiary;
    }
    return Row(
      children: [
        Text(
          '$label: ',
          style: AppTypography.labelSm.copyWith(fontSize: 10, color: AppColors.outline),
        ),
        Text(
          value.toStringAsFixed(2),
          style: AppTypography.numericTable.copyWith(
            fontSize: 11,
            color: valColor,
            fontWeight: isClose ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _CandlestickPainter extends CustomPainter {
  final List<CandleData> candles;
  final CandleData? inspectedCandle;
  final double? currentPrice;
  final String currencySymbol;
  final String selectedInterval;
  final bool showSma20;
  final bool showEma20;
  final bool showRsi;
  final bool showMacd;
  final List<double?> sma20;
  final List<double?> ema20;
  final List<double?> rsi14;
  final Map<String, List<double?>> macd;
  final double panOffset;
  final double zoomScale;

  _CandlestickPainter({
    required this.candles,
    this.inspectedCandle,
    this.currentPrice,
    required this.currencySymbol,
    required this.selectedInterval,
    required this.showSma20,
    required this.showEma20,
    required this.showRsi,
    required this.showMacd,
    required this.sma20,
    required this.ema20,
    required this.rsi14,
    required this.macd,
    required this.panOffset,
    required this.zoomScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    // Allocate right axis (54px)
    const axisWidth = 54.0;
    final chartWidth = math.max(size.width - axisWidth, 50.0);

    // Dynamic panel heights
    double rsiHeight = showRsi ? 48.0 : 0.0;
    double macdHeight = showMacd ? 48.0 : 0.0;
    double timeAxisHeight = 16.0;

    double availableMain = size.height - rsiHeight - macdHeight - timeAxisHeight;
    double mainChartHeight = availableMain * 0.78;
    double volumeHeight = availableMain * 0.20;

    final candleWidth = CandlestickChartView.calculateCandleWidth(chartWidth, candles.length, zoomScale);
    final bodyWidth = (candleWidth * 0.72).clamp(2.5, 14.0);

    // 1. Calculate price range bounds from VISIBLE candles in current viewport
    double minPrice = double.infinity;
    double maxPrice = double.negativeInfinity;
    double maxVol = 0;

    int visibleCandlesCount = 0;
    for (int i = 0; i < candles.length; i++) {
      final x = panOffset + (i * candleWidth + candleWidth / 2);
      if (x >= -candleWidth && x <= chartWidth + candleWidth) {
        final c = candles[i];
        if (c.low < minPrice) minPrice = c.low;
        if (c.high > maxPrice) maxPrice = c.high;
        if (c.volume > maxVol) maxVol = c.volume;
        visibleCandlesCount++;
      }
    }

    if (visibleCandlesCount == 0 || minPrice == double.infinity) {
      for (final c in candles) {
        if (c.low < minPrice) minPrice = c.low;
        if (c.high > maxPrice) maxPrice = c.high;
        if (c.volume > maxVol) maxVol = c.volume;
      }
    }

    if (minPrice >= maxPrice) {
      minPrice *= 0.99;
      maxPrice *= 1.01;
    }

    // 10% vertical padding buffer for professional headroom and footroom
    final rawRange = (maxPrice - minPrice).clamp(0.01, double.infinity);
    final vPadding = rawRange * 0.10;
    final paddedMin = minPrice - vPadding;
    final paddedMax = maxPrice + vPadding;
    final priceRange = paddedMax - paddedMin;

    final bullPaint = Paint()..color = AppColors.secondary;
    final bearPaint = Paint()..color = AppColors.tertiary;
    final gridPaint = Paint()
      ..color = AppColors.borderSubtle.withOpacity(0.4)
      ..strokeWidth = 0.8;

    // Draw horizontal grid lines across chartWidth
    final gridLevels = [0.12, 0.38, 0.64, 0.88];
    for (final level in gridLevels) {
      final y = mainChartHeight * level;
      final priceAtLevel = paddedMax - (level * priceRange);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
      _drawAxisText(canvas, priceAtLevel.toStringAsFixed(1), chartWidth + 4, y);
    }

    // Volume baseline
    final volBaseY = mainChartHeight + volumeHeight;
    canvas.drawLine(Offset(0, volBaseY), Offset(chartWidth, volBaseY), gridPaint);

    // Right Y-axis background & divider
    canvas.drawRect(
      Rect.fromLTWH(chartWidth, 0, axisWidth, size.height),
      Paint()..color = AppColors.surfaceContainer,
    );
    canvas.drawLine(
      Offset(chartWidth, 0),
      Offset(chartWidth, size.height),
      Paint()..color = AppColors.borderSubtle..strokeWidth = 1.0,
    );

    // ============================================
    // CLIP CANVAS FOR CANDLE & INDICATOR DRAWING
    // ============================================
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, chartWidth, volBaseY));

    int? inspectedIndex;

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      if (c == inspectedCandle) {
        inspectedIndex = i;
      }
      final isBull = c.isBullish;
      final paint = isBull ? bullPaint : bearPaint;
      final x = panOffset + (i * candleWidth + candleWidth / 2);

      // Skip off-screen candles for high performance
      if (x < -candleWidth || x > chartWidth + candleWidth) continue;

      final highY = mainChartHeight - ((c.high - paddedMin) / priceRange) * mainChartHeight;
      final lowY = mainChartHeight - ((c.low - paddedMin) / priceRange) * mainChartHeight;
      final openY = mainChartHeight - ((c.open - paddedMin) / priceRange) * mainChartHeight;
      final closeY = mainChartHeight - ((c.close - paddedMin) / priceRange) * mainChartHeight;

      // Wick
      canvas.drawLine(
        Offset(x, highY),
        Offset(x, lowY),
        paint..strokeWidth = 1.2,
      );

      // Body
      final topY = math.min(openY, closeY);
      final bodyH = (openY - closeY).abs().clamp(1.5, mainChartHeight);
      final bodyRect = Rect.fromLTWH(x - bodyWidth / 2, topY, bodyWidth, bodyH);
      canvas.drawRect(bodyRect, paint);

      // Volume bar
      if (maxVol > 0) {
        final volBarH = (c.volume / maxVol) * (volumeHeight - 2);
        final volRect = Rect.fromLTWH(
          x - bodyWidth / 2,
          volBaseY - volBarH,
          bodyWidth,
          volBarH,
        );
        canvas.drawRect(
          volRect,
          Paint()..color = (isBull ? AppColors.secondary : AppColors.tertiary).withOpacity(0.35),
        );
      }
    }

    // 5. Draw Overlaid Technical Indicators (SMA 20, EMA 20)
    if (showSma20 && sma20.isNotEmpty) {
      _drawIndicatorLine(canvas, sma20, paddedMin, priceRange, mainChartHeight, candleWidth, const Color(0xFFFFB300));
    }
    if (showEma20 && ema20.isNotEmpty) {
      _drawIndicatorLine(canvas, ema20, paddedMin, priceRange, mainChartHeight, candleWidth, const Color(0xFF00E5FF));
    }

    canvas.restore(); // END CLIPPING

    // 6. Draw Real-Time LTP guideline and badge for the latest candle
    final latestCandle = candles.last;
    final latestY = mainChartHeight - ((latestCandle.close - paddedMin) / priceRange) * mainChartHeight;
    final latestColor = latestCandle.isBullish ? AppColors.secondary : AppColors.tertiary;

    _drawDashedLine(
      canvas,
      Offset(0, latestY),
      Offset(chartWidth, latestY),
      Paint()..color = latestColor.withOpacity(0.7)..strokeWidth = 1.0,
    );

    _drawBadge(
      canvas,
      latestCandle.close.toStringAsFixed(1),
      chartWidth + 3,
      latestY,
      latestColor,
      Colors.white,
    );

    // 7. Touch crosshair & inspect badge
    if (inspectedIndex != null && inspectedCandle != null) {
      final inspectX = panOffset + (inspectedIndex * candleWidth + candleWidth / 2);
      final inspectY = mainChartHeight - ((inspectedCandle!.close - paddedMin) / priceRange) * mainChartHeight;

      if (inspectX >= 0 && inspectX <= chartWidth) {
        canvas.drawLine(
          Offset(inspectX, 0),
          Offset(inspectX, volBaseY),
          Paint()..color = AppColors.primaryBrand.withOpacity(0.7)..strokeWidth = 1.0,
        );

        _drawDashedLine(
          canvas,
          Offset(0, inspectY),
          Offset(chartWidth, inspectY),
          Paint()..color = AppColors.primaryBrand.withOpacity(0.7)..strokeWidth = 1.0,
        );

        _drawBadge(
          canvas,
          inspectedCandle!.close.toStringAsFixed(1),
          chartWidth + 3,
          inspectY,
          AppColors.primaryBrand,
          Colors.white,
        );
      }
    }

    // 8. Bottom X-Axis Time / Date Labels
    final xTimeY = volBaseY + 3;
    final timeStep = math.max(candles.length ~/ 4, 1);
    for (int i = 0; i < candles.length; i += timeStep) {
      final x = panOffset + (i * candleWidth + candleWidth / 2);
      if (x > 10 && x < chartWidth - 30) {
        final date = DateTime.fromMillisecondsSinceEpoch(candles[i].timestamp * 1000);
        final label = selectedInterval.contains('d') || selectedInterval.contains('w') || selectedInterval.contains('mo')
            ? '${date.day}/${date.month}'
            : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        _drawAxisText(canvas, label, x - 12, xTimeY);
      }
    }

    // 9. RSI Oscillator Sub-Panel
    double currentSubPanelTop = volBaseY + timeAxisHeight;
    if (showRsi && rsi14.isNotEmpty) {
      _drawRsiPanel(canvas, currentSubPanelTop, rsiHeight, chartWidth, candleWidth);
      currentSubPanelTop += rsiHeight;
    }

    // 10. MACD Oscillator Sub-Panel
    if (showMacd && macd.isNotEmpty) {
      _drawMacdPanel(canvas, currentSubPanelTop, macdHeight, chartWidth, candleWidth);
    }
  }

  void _drawIndicatorLine(
    Canvas canvas,
    List<double?> values,
    double minPrice,
    double priceRange,
    double chartHeight,
    double candleWidth,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool hasStarted = false;

    for (int i = 0; i < values.length; i++) {
      final val = values[i];
      if (val == null) continue;

      final x = panOffset + (i * candleWidth + candleWidth / 2);
      final y = chartHeight - ((val - minPrice) / priceRange) * chartHeight;

      if (!hasStarted) {
        path.moveTo(x, y);
        hasStarted = true;
      } else {
        path.lineTo(x, y);
      }
    }

    if (hasStarted) {
      canvas.drawPath(path, paint);
    }
  }

  void _drawRsiPanel(Canvas canvas, double topY, double panelHeight, double chartWidth, double candleWidth) {
    // Background and boundary
    canvas.drawLine(Offset(0, topY), Offset(chartWidth, topY), Paint()..color = AppColors.borderSubtle..strokeWidth = 0.8);
    _drawAxisText(canvas, 'RSI(14)', chartWidth + 4, topY + 4);

    // 70 and 30 reference lines
    final y70 = topY + panelHeight * 0.3;
    final y30 = topY + panelHeight * 0.7;
    final refPaint = Paint()..color = const Color(0xFFAB47BC).withOpacity(0.35)..strokeWidth = 0.8;
    _drawDashedLine(canvas, Offset(0, y70), Offset(chartWidth, y70), refPaint);
    _drawDashedLine(canvas, Offset(0, y30), Offset(chartWidth, y30), refPaint);
    _drawAxisText(canvas, '70', chartWidth + 4, y70);
    _drawAxisText(canvas, '30', chartWidth + 4, y30);

    // RSI Path
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, topY, chartWidth, panelHeight));

    final rsiPath = Path();
    bool started = false;

    for (int i = 0; i < rsi14.length; i++) {
      final val = rsi14[i];
      if (val == null) continue;

      final x = panOffset + (i * candleWidth + candleWidth / 2);
      final y = topY + panelHeight - (val / 100.0) * panelHeight;

      if (!started) {
        rsiPath.moveTo(x, y);
        started = true;
      } else {
        rsiPath.lineTo(x, y);
      }
    }

    if (started) {
      canvas.drawPath(rsiPath, Paint()..color = const Color(0xFFAB47BC)..strokeWidth = 1.4..style = PaintingStyle.stroke);
    }
    canvas.restore();
  }

  void _drawMacdPanel(Canvas canvas, double topY, double panelHeight, double chartWidth, double candleWidth) {
    canvas.drawLine(Offset(0, topY), Offset(chartWidth, topY), Paint()..color = AppColors.borderSubtle..strokeWidth = 0.8);
    _drawAxisText(canvas, 'MACD', chartWidth + 4, topY + 4);

    final zeroY = topY + panelHeight * 0.5;
    canvas.drawLine(Offset(0, zeroY), Offset(chartWidth, zeroY), Paint()..color = AppColors.borderSubtle.withOpacity(0.4)..strokeWidth = 0.8);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, topY, chartWidth, panelHeight));

    final macdLine = macd['macd'] ?? [];
    final signalLine = macd['signal'] ?? [];
    final histogram = macd['histogram'] ?? [];

    // Histogram bars
    final barWidth = (candleWidth * 0.5).clamp(1.0, 6.0);
    for (int i = 0; i < histogram.length; i++) {
      final h = histogram[i];
      if (h == null) continue;

      final x = panOffset + (i * candleWidth + candleWidth / 2);
      final barH = (h * 4.0).clamp(-panelHeight * 0.45, panelHeight * 0.45);
      final isBull = h >= 0;
      final paint = Paint()..color = (isBull ? AppColors.secondary : AppColors.tertiary).withOpacity(0.6);

      canvas.drawRect(
        Rect.fromLTWH(x - barWidth / 2, isBull ? zeroY - barH : zeroY, barWidth, barH.abs()),
        paint,
      );
    }

    // MACD Line
    _drawSubLine(canvas, macdLine, zeroY, panelHeight, candleWidth, const Color(0xFF29B6F6));
    // Signal Line
    _drawSubLine(canvas, signalLine, zeroY, panelHeight, candleWidth, const Color(0xFFFF7043));

    canvas.restore();
  }

  void _drawSubLine(Canvas canvas, List<double?> series, double zeroY, double panelHeight, double candleWidth, Color color) {
    final path = Path();
    bool started = false;

    for (int i = 0; i < series.length; i++) {
      final v = series[i];
      if (v == null) continue;

      final x = panOffset + (i * candleWidth + candleWidth / 2);
      final y = zeroY - (v * 4.0).clamp(-panelHeight * 0.45, panelHeight * 0.45);

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    if (started) {
      canvas.drawPath(path, Paint()..color = color..strokeWidth = 1.2..style = PaintingStyle.stroke);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint, {double dashWidth = 4, double dashSpace = 3}) {
    double currentX = start.dx;
    while (currentX < end.dx) {
      canvas.drawLine(
        Offset(currentX, start.dy),
        Offset(math.min(currentX + dashWidth, end.dx), start.dy),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  void _drawAxisText(Canvas canvas, String text, double x, double y) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 9,
        color: AppColors.outline,
        fontFamily: 'monospace',
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x, y - textPainter.height / 2));
  }

  void _drawBadge(Canvas canvas, String text, double x, double y, Color bg, Color fg) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.bold,
        color: fg,
        fontFamily: 'monospace',
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final badgeWidth = textPainter.width + 6;
    final badgeHeight = textPainter.height + 3;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y - badgeHeight / 2, badgeWidth, badgeHeight),
      const Radius.circular(3),
    );

    canvas.drawRRect(badgeRect, Paint()..color = bg);
    textPainter.paint(canvas, Offset(x + 3, y - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.inspectedCandle != inspectedCandle ||
        oldDelegate.currentPrice != currentPrice ||
        oldDelegate.showSma20 != showSma20 ||
        oldDelegate.showEma20 != showEma20 ||
        oldDelegate.showRsi != showRsi ||
        oldDelegate.showMacd != showMacd ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.zoomScale != zoomScale;
  }
}
