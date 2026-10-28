import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/loading_state_widget.dart';
import '../../../../shared/widgets/error_state_widget.dart';

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

  factory CandleData.fromJson(Map<String, dynamic> json) {
    return CandleData(
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      open: (json['open'] as num?)?.toDouble() ?? 0.0,
      high: (json['high'] as num?)?.toDouble() ?? 0.0,
      low: (json['low'] as num?)?.toDouble() ?? 0.0,
      close: (json['close'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CandlestickChartView extends StatefulWidget {
  final String symbol;
  final List<CandleData> candles;
  final bool isLoading;
  final String? errorMessage;
  final String selectedInterval;
  final ValueChanged<String> onIntervalChanged;
  final VoidCallback? onRetry;

  const CandlestickChartView({
    super.key,
    required this.symbol,
    required this.candles,
    this.isLoading = false,
    this.errorMessage,
    required this.selectedInterval,
    required this.onIntervalChanged,
    this.onRetry,
  });

  @override
  State<CandlestickChartView> createState() => _CandlestickChartViewState();
}

class _CandlestickChartViewState extends State<CandlestickChartView> {
  CandleData? _inspectedCandle;

  @override
  void didUpdateWidget(covariant CandlestickChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.selectedInterval != widget.selectedInterval ||
        oldWidget.candles != widget.candles) {
      _inspectedCandle = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCandle = _inspectedCandle ?? (widget.candles.isNotEmpty ? widget.candles.last : null);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with OHLCV Telemetry and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(widget.symbol, style: AppTypography.headlineSm.copyWith(fontSize: 14)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Text(
                      'SIMULATED • ${widget.selectedInterval.toUpperCase()}',
                      style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.warning, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (activeCandle != null)
                Text(
                  'Vol: ${(activeCandle.volume / 1000).toStringAsFixed(1)}K',
                  style: AppTypography.labelSm.copyWith(fontSize: 10, color: AppColors.outline),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Active Crosshair OHLC readout
          if (activeCandle != null)
            Row(
              children: [
                _buildOhlcItem('O', activeCandle.open),
                const SizedBox(width: 8),
                _buildOhlcItem('H', activeCandle.high),
                const SizedBox(width: 8),
                _buildOhlcItem('L', activeCandle.low),
                const SizedBox(width: 8),
                _buildOhlcItem('C', activeCandle.close, isClose: true, isBull: activeCandle.isBullish),
              ],
            ),
          const SizedBox(height: 10),

          // Chart Body
          SizedBox(
            height: 180,
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
                              return GestureDetector(
                                onHorizontalDragUpdate: (details) {
                                  _handleInspect(details.localPosition.dx, constraints.maxWidth);
                                },
                                onTapDown: (details) {
                                  _handleInspect(details.localPosition.dx, constraints.maxWidth);
                                },
                                onLongPressEnd: (_) {
                                  setState(() => _inspectedCandle = null);
                                },
                                child: CustomPaint(
                                  size: Size(constraints.maxWidth, 180),
                                  painter: _CandlestickPainter(
                                    candles: widget.candles,
                                    inspectedCandle: _inspectedCandle,
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          const SizedBox(height: 8),

          // Timeframe Selector Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ['1m', '5m', '15m', '1h', '1d', '1w'].map((interval) {
              final isSelected = widget.selectedInterval == interval;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => widget.onIntervalChanged(interval),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryBrand.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryBrand : AppColors.borderSubtle,
                      ),
                    ),
                    child: Text(
                      interval.toUpperCase(),
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 10,
                        color: isSelected ? AppColors.primary : AppColors.outline,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _handleInspect(double touchX, double width) {
    if (widget.candles.isEmpty || width <= 0) return;
    final candleWidth = width / widget.candles.length;
    final index = (touchX / candleWidth).clamp(0, widget.candles.length - 1).toInt();
    setState(() {
      _inspectedCandle = widget.candles[index];
    });
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

  _CandlestickPainter({required this.candles, this.inspectedCandle});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    double minPrice = double.infinity;
    double maxPrice = double.negativeInfinity;
    double maxVol = 0;

    for (final c in candles) {
      if (c.low < minPrice) minPrice = c.low;
      if (c.high > maxPrice) maxPrice = c.high;
      if (c.volume > maxVol) maxVol = c.volume;
    }

    // Add 2% padding
    final priceRange = (maxPrice - minPrice).clamp(1.0, double.infinity);
    final chartHeight = size.height * 0.75;
    final volumeHeight = size.height * 0.22;
    final candleWidth = size.width / candles.length;
    final bodyWidth = (candleWidth * 0.65).clamp(2.0, 12.0);

    final bullPaint = Paint()..color = AppColors.secondary;
    final bearPaint = Paint()..color = AppColors.tertiary;
    final linePaint = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1.0;

    // Draw horizontal grid lines
    canvas.drawLine(Offset(0, chartHeight * 0.25), Offset(size.width, chartHeight * 0.25), linePaint);
    canvas.drawLine(Offset(0, chartHeight * 0.5), Offset(size.width, chartHeight * 0.5), linePaint);
    canvas.drawLine(Offset(0, chartHeight * 0.75), Offset(size.width, chartHeight * 0.75), linePaint);
    canvas.drawLine(Offset(0, size.height - volumeHeight), Offset(size.width, size.height - volumeHeight), linePaint);

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final isBull = c.isBullish;
      final paint = isBull ? bullPaint : bearPaint;

      final x = i * candleWidth + candleWidth / 2;

      // Price coordinates
      final highY = chartHeight - ((c.high - minPrice) / priceRange) * chartHeight;
      final lowY = chartHeight - ((c.low - minPrice) / priceRange) * chartHeight;
      final openY = chartHeight - ((c.open - minPrice) / priceRange) * chartHeight;
      final closeY = chartHeight - ((c.close - minPrice) / priceRange) * chartHeight;

      // Draw wick
      canvas.drawLine(
        Offset(x, highY),
        Offset(x, lowY),
        Paint()
          ..color = paint.color
          ..strokeWidth = 1.2,
      );

      // Draw candle body
      final topY = Math.min(openY, closeY);
      final bodyH = (openY - closeY).abs().clamp(1.5, chartHeight);
      final bodyRect = Rect.fromLTWH(x - bodyWidth / 2, topY, bodyWidth, bodyH);
      canvas.drawRect(bodyRect, paint);

      // Draw volume bar
      if (maxVol > 0) {
        final volBarH = (c.volume / maxVol) * volumeHeight;
        final volRect = Rect.fromLTWH(
          x - bodyWidth / 2,
          size.height - volBarH,
          bodyWidth,
          volBarH,
        );
        canvas.drawRect(
          volRect,
          Paint()..color = paint.color.withOpacity(0.35),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) {
    return oldDelegate.candles != candles || oldDelegate.inspectedCandle != inspectedCandle;
  }
}

class Math {
  static double min(double a, double b) => a < b ? a : b;
  static double max(double a, double b) => a > b ? a : b;
}
