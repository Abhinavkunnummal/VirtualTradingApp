class InstrumentModel {
  final String symbol;
  final String name;
  final String exchange;
  final String category; // EQUITY, COMMODITY, CRYPTO, US
  final double price;
  final double change;
  final double changePercent;
  final bool isPositive;
  final bool isSimulated;

  const InstrumentModel({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.category,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.isPositive,
    this.isSimulated = true,
  });

  factory InstrumentModel.fromJson(Map<String, dynamic> json) {
    final price = (json['price'] as num?)?.toDouble() ??
        (json['basePrice'] as num?)?.toDouble() ??
        0.0;
    final change = (json['change'] as num?)?.toDouble() ?? 0.0;
    final changePercent = (json['changePercent'] as num?)?.toDouble() ?? 0.0;

    return InstrumentModel(
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? json['symbol'] as String? ?? '',
      exchange: json['exchange'] as String? ?? 'NSE',
      category: json['category'] as String? ?? 'EQUITY',
      price: price,
      change: change,
      changePercent: changePercent,
      isPositive: change >= 0,
      isSimulated: json['status'] == 'SIMULATED' || json['isSimulated'] == true,
    );
  }
}

class WatchlistModel {
  final String id;
  final String name;
  final List<String> instruments;
  final bool isDefault;

  const WatchlistModel({
    required this.id,
    required this.name,
    required this.instruments,
    this.isDefault = false,
  });

  factory WatchlistModel.fromJson(Map<String, dynamic> json) {
    return WatchlistModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      instruments: (json['instruments'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}
