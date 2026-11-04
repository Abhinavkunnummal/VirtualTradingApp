class PaperAccountModel {
  final String id;
  final String accountName;
  final String baseCurrency;
  final double startingCapital;
  final double availableCash;
  final double reservedMargin;
  final bool isSimulated;
  final String? disclaimer;

  const PaperAccountModel({
    required this.id,
    required this.accountName,
    required this.baseCurrency,
    required this.startingCapital,
    required this.availableCash,
    required this.reservedMargin,
    this.isSimulated = true,
    this.disclaimer,
  });

  factory PaperAccountModel.fromJson(Map<String, dynamic> json) {
    return PaperAccountModel(
      id: json['id'] as String? ?? '',
      accountName: json['accountName'] as String? ?? 'Sandbox v2.4 (Default)',
      baseCurrency: json['baseCurrency'] as String? ?? 'INR',
      startingCapital: (json['startingCapital'] as num?)?.toDouble() ?? 0.0,
      availableCash: (json['availableCash'] as num?)?.toDouble() ?? 0.0,
      reservedMargin: (json['reservedMargin'] as num?)?.toDouble() ?? 0.0,
      isSimulated: json['isSimulated'] as bool? ?? true,
      disclaimer: json['disclaimer'] as String?,
    );
  }
}

class HoldingModel {
  final String id;
  final String symbol;
  final String exchange;
  final String product;
  final int quantity;
  final double averageBuyPrice;
  final double ltp;
  final double investedValue;
  final double currentValue;
  final double unrealizedPnl;
  final double unrealizedPnlPercent;
  final double? stopLoss;
  final double? targetPrice;

  const HoldingModel({
    required this.id,
    required this.symbol,
    required this.exchange,
    this.product = 'CNC',
    required this.quantity,
    required this.averageBuyPrice,
    required this.ltp,
    required this.investedValue,
    required this.currentValue,
    required this.unrealizedPnl,
    required this.unrealizedPnlPercent,
    this.stopLoss,
    this.targetPrice,
  });

  factory HoldingModel.fromJson(Map<String, dynamic> json) {
    return HoldingModel(
      id: json['id'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      exchange: json['exchange'] as String? ?? 'NSE',
      product: json['product'] as String? ?? 'CNC',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      averageBuyPrice: (json['averageBuyPrice'] as num?)?.toDouble() ?? (json['averagePrice'] as num?)?.toDouble() ?? 0.0,
      ltp: (json['ltp'] as num?)?.toDouble() ?? 0.0,
      investedValue: (json['investedValue'] as num?)?.toDouble() ?? 0.0,
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0.0,
      unrealizedPnl: (json['unrealizedPnl'] as num?)?.toDouble() ?? 0.0,
      unrealizedPnlPercent: (json['unrealizedPnlPercent'] as num?)?.toDouble() ?? 0.0,
      stopLoss: (json['stopLoss'] as num?)?.toDouble() ?? (json['stopLossPrice'] as num?)?.toDouble(),
      targetPrice: (json['targetPrice'] as num?)?.toDouble(),
    );
  }
}

class PortfolioModel {
  final double totalPortfolioValue;
  final double availableCash;
  final double investedValue;
  final double startingCapital;
  final double totalPnl;
  final double totalPnlPercent;
  final bool isSimulated;
  final List<HoldingModel> holdings;

  const PortfolioModel({
    required this.totalPortfolioValue,
    required this.availableCash,
    required this.investedValue,
    required this.startingCapital,
    required this.totalPnl,
    required this.totalPnlPercent,
    this.isSimulated = true,
    required this.holdings,
  });

  factory PortfolioModel.fromJson(Map<String, dynamic> json) {
    final rawHoldings = json['holdings'] as List<dynamic>? ?? [];
    return PortfolioModel(
      totalPortfolioValue: (json['totalPortfolioValue'] as num?)?.toDouble() ?? 0.0,
      availableCash: (json['availableCash'] as num?)?.toDouble() ?? 0.0,
      investedValue: (json['investedValue'] as num?)?.toDouble() ?? 0.0,
      startingCapital: (json['startingCapital'] as num?)?.toDouble() ?? 0.0,
      totalPnl: (json['totalPnl'] as num?)?.toDouble() ?? 0.0,
      totalPnlPercent: (json['totalPnlPercent'] as num?)?.toDouble() ?? 0.0,
      isSimulated: json['isSimulated'] as bool? ?? true,
      holdings: rawHoldings.map((h) => HoldingModel.fromJson(h as Map<String, dynamic>)).toList(),
    );
  }

  // Fallback demo state
  factory PortfolioModel.demo() {
    return const PortfolioModel(
      totalPortfolioValue: 1248750.00,
      availableCash: 425000.00,
      investedValue: 823750.00,
      startingCapital: 1000000.00,
      totalPnl: 48750.00,
      totalPnlPercent: 4.06,
      isSimulated: true,
      holdings: [
        HoldingModel(
          id: 'hold_rel',
          symbol: 'RELIANCE',
          exchange: 'NSE',
          quantity: 150,
          averageBuyPrice: 2880.00,
          ltp: 2945.50,
          investedValue: 432000.00,
          currentValue: 441825.00,
          unrealizedPnl: 9825.00,
          unrealizedPnlPercent: 2.27,
        ),
        HoldingModel(
          id: 'hold_hdfc',
          symbol: 'HDFCBANK',
          exchange: 'NSE',
          quantity: 200,
          averageBuyPrice: 1680.00,
          ltp: 1720.80,
          investedValue: 336000.00,
          currentValue: 344160.00,
          unrealizedPnl: 8160.00,
          unrealizedPnlPercent: 2.43,
        ),
        HoldingModel(
          id: 'hold_tcs',
          symbol: 'TCS',
          exchange: 'NSE',
          quantity: 50,
          averageBuyPrice: 4180.00,
          ltp: 4120.00,
          investedValue: 209000.00,
          currentValue: 206000.00,
          unrealizedPnl: -3000.00,
          unrealizedPnlPercent: -1.44,
        ),
      ],
    );
  }
}

class TradeHistoryModel {
  final String id;
  final String symbol;
  final String exchange;
  final String product;
  final String side;
  final int quantity;
  final double entryPrice;
  final double exitPrice;
  final double realizedPnl;
  final double realizedPnlPercent;
  final double fees;
  final DateTime closedAt;

  const TradeHistoryModel({
    required this.id,
    required this.symbol,
    required this.exchange,
    required this.product,
    required this.side,
    required this.quantity,
    required this.entryPrice,
    required this.exitPrice,
    required this.realizedPnl,
    required this.realizedPnlPercent,
    required this.fees,
    required this.closedAt,
  });

  factory TradeHistoryModel.fromJson(Map<String, dynamic> json) {
    return TradeHistoryModel(
      id: json['id'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      exchange: json['exchange'] as String? ?? 'NSE',
      product: json['product'] as String? ?? 'CNC',
      side: json['side'] as String? ?? 'SELL',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      entryPrice: (json['entryPrice'] as num?)?.toDouble() ?? 0.0,
      exitPrice: (json['exitPrice'] as num?)?.toDouble() ?? 0.0,
      realizedPnl: (json['realizedPnl'] as num?)?.toDouble() ?? 0.0,
      realizedPnlPercent: (json['realizedPnlPercent'] as num?)?.toDouble() ?? 0.0,
      fees: (json['fees'] as num?)?.toDouble() ?? 0.0,
      closedAt: DateTime.tryParse(json['closedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class WalletTransactionModel {
  final String id;
  final String type;
  final double amount;
  final double balanceAfter;
  final String description;
  final DateTime timestamp;

  const WalletTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    required this.timestamp,
  });

  DateTime get createdAt => timestamp;

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'TRANSACTION',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class PnlSummaryModel {
  final double totalRealizedPnl;
  final double totalUnrealizedPnl;
  final double totalPnl;
  final int totalTrades;
  final int profitableTrades;
  final double winRate;

  const PnlSummaryModel({
    required this.totalRealizedPnl,
    required this.totalUnrealizedPnl,
    required this.totalPnl,
    required this.totalTrades,
    required this.profitableTrades,
    required this.winRate,
  });

  factory PnlSummaryModel.fromJson(Map<String, dynamic> json) {
    return PnlSummaryModel(
      totalRealizedPnl: (json['totalRealizedPnl'] as num?)?.toDouble() ?? 0.0,
      totalUnrealizedPnl: (json['totalUnrealizedPnl'] as num?)?.toDouble() ?? 0.0,
      totalPnl: (json['totalPnl'] as num?)?.toDouble() ?? 0.0,
      totalTrades: (json['totalTrades'] as num?)?.toInt() ?? 0,
      profitableTrades: (json['profitableTrades'] as num?)?.toInt() ?? 0,
      winRate: (json['winRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory PnlSummaryModel.zero() {
    return const PnlSummaryModel(
      totalRealizedPnl: 0.0,
      totalUnrealizedPnl: 0.0,
      totalPnl: 0.0,
      totalTrades: 0,
      profitableTrades: 0,
      winRate: 0.0,
    );
  }
}
