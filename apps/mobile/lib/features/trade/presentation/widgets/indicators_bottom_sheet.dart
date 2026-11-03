import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/chart_indicator_config.dart';

class IndicatorsBottomSheet extends StatefulWidget {
  final List<ChartIndicatorConfig> indicators;
  final ValueChanged<List<ChartIndicatorConfig>> onChanged;
  final VoidCallback onReset;

  const IndicatorsBottomSheet({
    super.key,
    required this.indicators,
    required this.onChanged,
    required this.onReset,
  });

  @override
  State<IndicatorsBottomSheet> createState() => _IndicatorsBottomSheetState();
}

class _IndicatorsBottomSheetState extends State<IndicatorsBottomSheet> {
  late List<ChartIndicatorConfig> _currentList;

  @override
  void initState() {
    super.initState();
    _currentList = List.of(widget.indicators);
  }

  void _updateIndicator(int index, ChartIndicatorConfig updated) {
    setState(() {
      _currentList[index] = updated;
    });
    widget.onChanged(_currentList);
  }

  void _resetToDefaults() {
    setState(() {
      _currentList = ChartIndicatorConfig.defaultIndicators();
    });
    widget.onReset();
  }

  Color _parseHexColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return AppColors.zerodhaBlue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Drag Handle
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
          const SizedBox(height: 12),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.functions, size: 20, color: AppColors.zerodhaBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Indicators & Studies',
                    style: AppTypography.headlineSm.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _resetToDefaults,
                    child: Text(
                      'Reset',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.kiteRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.outline),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: AppColors.tvBorder),

          // Scrollable List of Indicators
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _currentList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final ind = _currentList[index];
                final color = _parseHexColor(ind.color);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.tvCardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: ind.isEnabled
                          ? color.withOpacity(0.4)
                          : AppColors.tvBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Switch
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ind.name,
                              style: AppTypography.bodyMd.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: ind.isEnabled
                                    ? AppColors.onSurface
                                    : AppColors.outline,
                              ),
                            ),
                          ),
                          Switch(
                            value: ind.isEnabled,
                            activeColor: color,
                            onChanged: (val) {
                              _updateIndicator(index, ind.copyWith(isEnabled: val));
                            },
                          ),
                        ],
                      ),

                      // Parameter Sliders when enabled
                      if (ind.isEnabled) ...[
                        const SizedBox(height: 6),
                        if (ind.type == 'SMA' || ind.type == 'EMA' || ind.type == 'RSI')
                          _buildPeriodSlider(
                            label: 'Period: ${ind.period}',
                            value: ind.period.toDouble(),
                            min: ind.type == 'RSI' ? 5 : 5,
                            max: ind.type == 'RSI' ? 50 : 200,
                            divisions: ind.type == 'RSI' ? 45 : 39,
                            onChanged: (val) {
                              _updateIndicator(index, ind.copyWith(period: val.toInt()));
                            },
                          ),
                        if (ind.type == 'BOLLINGER') ...[
                          _buildPeriodSlider(
                            label: 'Period: ${ind.period}',
                            value: ind.period.toDouble(),
                            min: 5,
                            max: 50,
                            divisions: 45,
                            onChanged: (val) {
                              _updateIndicator(index, ind.copyWith(period: val.toInt()));
                            },
                          ),
                          _buildPeriodSlider(
                            label: 'StdDev Multiplier: ${ind.stdDev.toStringAsFixed(1)}σ',
                            value: ind.stdDev,
                            min: 1.0,
                            max: 3.5,
                            divisions: 5,
                            onChanged: (val) {
                              _updateIndicator(index, ind.copyWith(stdDev: val));
                            },
                          ),
                        ],
                        if (ind.type == 'MACD') ...[
                          _buildPeriodSlider(
                            label: 'Fast Period: ${ind.fastPeriod}',
                            value: ind.fastPeriod.toDouble(),
                            min: 5,
                            max: 25,
                            divisions: 20,
                            onChanged: (val) {
                              _updateIndicator(index, ind.copyWith(fastPeriod: val.toInt()));
                            },
                          ),
                          _buildPeriodSlider(
                            label: 'Slow Period: ${ind.slowPeriod}',
                            value: ind.slowPeriod.toDouble(),
                            min: 15,
                            max: 50,
                            divisions: 35,
                            onChanged: (val) {
                              _updateIndicator(index, ind.copyWith(slowPeriod: val.toInt()));
                            },
                          ),
                          _buildPeriodSlider(
                            label: 'Signal Period: ${ind.signalPeriod}',
                            value: ind.signalPeriod.toDouble(),
                            min: 3,
                            max: 15,
                            divisions: 12,
                            onChanged: (val) {
                              _updateIndicator(index, ind.copyWith(signalPeriod: val.toInt()));
                            },
                          ),
                        ],
                        if (ind.isPane)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 4),
                            child: Text(
                              'Renders in a dedicated sub-panel beneath the main price chart.',
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 10,
                                color: AppColors.outline,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.zerodhaBlue,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Apply & Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            style: AppTypography.labelSm.copyWith(
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        SliderTheme(
          data: const SliderThemeData(
            trackHeight: 2,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: AppColors.zerodhaBlue,
            inactiveTrackColor: AppColors.tvBorder,
            thumbColor: AppColors.zerodhaBlue,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
