import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:tradeverse_mobile/core/constants/api_constants.dart';
import 'package:tradeverse_mobile/core/network/api_client.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';

class LiveQuote {
  final String symbol;
  final double price;
  final double change;
  final double changePercent;
  final double high;
  final double low;
  final double volume;
  final DateTime timestamp;
  final String status;

  const LiveQuote({
    required this.symbol,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.high,
    required this.low,
    required this.volume,
    required this.timestamp,
    this.status = 'UNKNOWN',
  });

  factory LiveQuote.fromJson(Map<String, dynamic> json) {
    return LiveQuote(
      symbol: (json['symbol'] as String? ?? '').toUpperCase(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      change: (json['change'] as num?)?.toDouble() ?? 0.0,
      changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0.0,
      high: (json['high'] as num?)?.toDouble() ?? 0.0,
      low: (json['low'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: (json['status'] as String? ?? 'UNKNOWN').toUpperCase(),
    );
  }
}

final liveQuotesProvider =
    StateNotifierProvider<LiveQuotesNotifier, Map<String, LiveQuote>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return LiveQuotesNotifier(apiClient: apiClient);
});

final liveQuoteForSymbolProvider =
    Provider.family<LiveQuote?, String>((ref, symbol) {
  final quotes = ref.watch(liveQuotesProvider);
  return quotes[symbol.toUpperCase()];
});

class LiveQuotesNotifier extends StateNotifier<Map<String, LiveQuote>> {
  final ApiClient apiClient;
  io.Socket? _socket;
  Timer? _pollingTimer;
  bool _isFetching = false;

  static const List<String> _defaultTrackedSymbols = [
    'BTC/USDT',
    'ETH/USDT',
    'SOL/USDT',
    'RELIANCE',
    'TCS',
    'HDFCBANK',
    'INFY',
    'NIFTY 50',
    'SENSEX',
    'GOLD 1KG',
    'SILVER 30KG',
    'CRUDEOIL',
    'AAPL',
    'NVDA',
    'MSFT',
  ];
  final Set<String> _trackedSymbols = {..._defaultTrackedSymbols};

  LiveQuotesNotifier({required this.apiClient}) : super({}) {
    final bool isTest =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      _initSocket();
      _startPollingFallback();
    }
  }

  void _initSocket() {
    try {
      final base = ApiConstants.baseUrl.replaceAll('/api/v1', '');
      _socket = io.io(
        base,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .build(),
      );

      _socket?.onConnect((_) {
        _socket?.emit('join_ticker', {'symbols': _trackedSymbols.toList()});
      });

      _socket?.on('ticker_tick', (data) {
        if (data is Map<String, dynamic>) {
          _updateQuote(LiveQuote.fromJson(data));
        }
      });
    } catch (_) {
      // Non-fatal, polling fallback will handle ticks
    }
  }

  /// Subscribe to instruments opened by the user, including searched symbols.
  void trackSymbol(String symbol) {
    final normalized = symbol.trim().toUpperCase();
    if (normalized.isEmpty || !_trackedSymbols.add(normalized)) return;
    final bool isTest =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) return;
    if (_socket?.connected == true) {
      _socket?.emit('join_ticker', {'symbols': [normalized]});
    }
    _fetchLiveQuotes();
  }

  void _startPollingFallback() {
    // Initial fetch immediately
    _fetchLiveQuotes();

    // 1-second interval ensures tick-by-tick real-time sync with TradingView
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _fetchLiveQuotes();
    });
  }

  Future<void> _fetchLiveQuotes() async {
    final bool isTest =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest || _isFetching) return;
    _isFetching = true;
    try {
      final symbolsParam = _trackedSymbols.join(',');
      final res = await apiClient.get<Map<String, dynamic>>(
        '/market-data/quotes',
        queryParameters: {'symbols': symbolsParam, 'source': 'live'},
      );

      if (res.statusCode == 200 && res.data?['success'] == true) {
        final list = res.data!['quotes'] as List<dynamic>? ?? [];
        if (list.isNotEmpty) {
          final Map<String, LiveQuote> updated = Map.from(state);
          for (final item in list) {
            if (item is Map<String, dynamic>) {
              final quote = LiveQuote.fromJson(item);
              if (quote.symbol.isNotEmpty && quote.price > 0) {
                updated[quote.symbol] = quote;
              }
            }
          }
          state = updated;
        }
      }
    } catch (_) {
      // Transient error, next second tick will retry
    } finally {
      _isFetching = false;
    }
  }

  void _updateQuote(LiveQuote quote) {
    if (quote.symbol.isEmpty || quote.price <= 0) return;
    state = {
      ...state,
      quote.symbol: quote,
    };
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _socket?.dispose();
    super.dispose();
  }
}
