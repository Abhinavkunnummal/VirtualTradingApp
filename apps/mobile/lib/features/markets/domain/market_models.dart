class InstrumentModel {
  final String symbol;
  final String name;
  final String exchange;
  final String category; // EQUITY, INDEX, ETF, COMMODITY, CRYPTO, US
  final double price;
  final double change;
  final double changePercent;
  final bool isPositive;
  final bool isSimulated;
  final int lotSize;
  final double tickSize;
  final String? isin;
  final String? segment;
  final String currency;

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
    this.lotSize = 1,
    this.tickSize = 0.05,
    this.isin,
    this.segment,
    this.currency = 'INR',
  });

  factory InstrumentModel.fromJson(Map<String, dynamic> json) {
    final price = (json['price'] as num?)?.toDouble() ??
        (json['basePrice'] as num?)?.toDouble() ??
        0.0;
    final change = (json['change'] as num?)?.toDouble() ?? 0.0;
    final changePercent = (json['changePercent'] as num?)?.toDouble() ?? 0.0;
    final lotSize = (json['lotSize'] as num?)?.toInt() ?? 1;
    final tickSize = (json['tickSize'] as num?)?.toDouble() ?? 0.05;
    final category = json['category'] as String? ?? 'EQUITY';
    final exchange = json['exchange'] as String? ?? 'NSE';
    final currency = json['currency'] as String? ??
        (category == 'US' || category == 'CRYPTO' || exchange == 'US' || exchange == 'CRYPTO' ? 'USD' : 'INR');

    return InstrumentModel(
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? json['displayName'] as String? ?? json['symbol'] as String? ?? '',
      exchange: exchange,
      category: category,
      price: price,
      change: change,
      changePercent: changePercent,
      isPositive: change >= 0,
      isSimulated: json['status'] == 'SIMULATED' || json['isSimulated'] == true,
      lotSize: lotSize,
      tickSize: tickSize,
      isin: json['isin'] as String?,
      segment: json['segment'] as String?,
      currency: currency,
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'exchange': exchange,
    'category': category,
    'price': price,
    'change': change,
    'changePercent': changePercent,
    'isPositive': isPositive,
    'isSimulated': isSimulated,
    'lotSize': lotSize,
    'tickSize': tickSize,
    'isin': isin,
    'segment': segment,
    'currency': currency,
  };
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
