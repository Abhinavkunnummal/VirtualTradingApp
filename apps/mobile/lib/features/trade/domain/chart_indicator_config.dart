class ChartIndicatorConfig {
  final String id;
  final String name;
  final String type;
  final bool isEnabled;
  final int period;
  final int fastPeriod;
  final int slowPeriod;
  final int signalPeriod;
  final double stdDev;
  final String color;
  final bool isPane;

  const ChartIndicatorConfig({
    required this.id,
    required this.name,
    required this.type,
    this.isEnabled = false,
    this.period = 20,
    this.fastPeriod = 12,
    this.slowPeriod = 26,
    this.signalPeriod = 9,
    this.stdDev = 2.0,
    this.color = '#ff9800',
    this.isPane = false,
  });

  ChartIndicatorConfig copyWith({
    String? id,
    String? name,
    String? type,
    bool? isEnabled,
    int? period,
    int? fastPeriod,
    int? slowPeriod,
    int? signalPeriod,
    double? stdDev,
    String? color,
    bool? isPane,
  }) {
    return ChartIndicatorConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isEnabled: isEnabled ?? this.isEnabled,
      period: period ?? this.period,
      fastPeriod: fastPeriod ?? this.fastPeriod,
      slowPeriod: slowPeriod ?? this.slowPeriod,
      signalPeriod: signalPeriod ?? this.signalPeriod,
      stdDev: stdDev ?? this.stdDev,
      color: color ?? this.color,
      isPane: isPane ?? this.isPane,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'visible': isEnabled,
    'period': period,
    'fastPeriod': fastPeriod,
    'slowPeriod': slowPeriod,
    'signalPeriod': signalPeriod,
    'stdDev': stdDev,
    'color': color,
    'isPane': isPane,
  };

  factory ChartIndicatorConfig.fromJson(Map<String, dynamic> json) {
    return ChartIndicatorConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'SMA',
      isEnabled: (json['visible'] as bool?) ?? (json['isEnabled'] as bool?) ?? false,
      period: (json['period'] as num?)?.toInt() ?? 20,
      fastPeriod: (json['fastPeriod'] as num?)?.toInt() ?? 12,
      slowPeriod: (json['slowPeriod'] as num?)?.toInt() ?? 26,
      signalPeriod: (json['signalPeriod'] as num?)?.toInt() ?? 9,
      stdDev: (json['stdDev'] as num?)?.toDouble() ?? 2.0,
      color: json['color'] as String? ?? '#ff9800',
      isPane: json['isPane'] as bool? ?? false,
    );
  }

  static List<ChartIndicatorConfig> defaultIndicators() => const [
    ChartIndicatorConfig(
      id: 'ema',
      name: 'EMA (Exponential MA)',
      type: 'EMA',
      isEnabled: true,
      period: 20,
      color: '#2196f3',
    ),
    ChartIndicatorConfig(
      id: 'sma',
      name: 'SMA (Simple MA)',
      type: 'SMA',
      isEnabled: false,
      period: 20,
      color: '#ff9800',
    ),
    ChartIndicatorConfig(
      id: 'bollinger',
      name: 'Bollinger Bands',
      type: 'BOLLINGER',
      isEnabled: false,
      period: 20,
      stdDev: 2.0,
      color: '#ab47bc',
    ),
    ChartIndicatorConfig(
      id: 'vwap',
      name: 'VWAP',
      type: 'VWAP',
      isEnabled: false,
      color: '#e91e63',
    ),
    ChartIndicatorConfig(
      id: 'volume',
      name: 'Volume Overlay',
      type: 'VOLUME',
      isEnabled: true,
      color: '#26a69a',
    ),
    ChartIndicatorConfig(
      id: 'rsi',
      name: 'RSI (Relative Strength)',
      type: 'RSI',
      isEnabled: false,
      period: 14,
      color: '#9c27b0',
      isPane: true,
    ),
    ChartIndicatorConfig(
      id: 'macd',
      name: 'MACD (Moving Avg Convergence)',
      type: 'MACD',
      isEnabled: false,
      fastPeriod: 12,
      slowPeriod: 26,
      signalPeriod: 9,
      color: '#2962ff',
      isPane: true,
    ),
  ];
}
