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
  String? _authToken;
  Timer? _pollingTimer;
  bool _isFetching = false;
  Map<String, dynamic>? _activeChartSubscription;
  void Function()? _onChartReconnect;
  final List<void Function(Map<String, dynamic>)> _chartTickListeners = [];

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

  void _initSocket({String? token}) {
    try {
      _authToken = token ?? _authToken;
      final base = ApiConstants.baseUrl.replaceAll('/api/v1', '');
      final options = io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000);

      if (_authToken != null && _authToken!.isNotEmpty) {
        options.setAuth({'token': _authToken});
      }

      _socket = io.io(
        base,
        options.build(),
      );

      _socket?.onConnect((_) {
        _socket?.emit('join_ticker', {'symbols': _trackedSymbols.toList()});
        if (_activeChartSubscription != null) {
          _socket?.emit('chart:subscribe', _activeChartSubscription);
          _onChartReconnect?.call();
        }
      });

      _socket?.on('ticker_tick', (data) {
        if (data is Map<String, dynamic>) {
          _updateQuote(LiveQuote.fromJson(data));
        }
      });

      _socket?.on('chart:tick', (data) {
        if (data is Map<String, dynamic>) {
          for (final listener in List.of(_chartTickListeners)) {
            listener(data);
          }
        }
      });
    } catch (_) {
      // Non-fatal, polling fallback will handle ticks
    }
  }

  /// Subscribe to TradingView-style Lightweight Chart live streaming ticks
  void subscribeChart({
    required String symbol,
    required String interval,
    void Function()? onReconnect,
  }) {
    _activeChartSubscription = {
      'symbol': symbol,
      'interval': interval,
    };
    _onChartReconnect = onReconnect;
    final bool isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest && _socket?.connected == true) {
      _socket?.emit('chart:subscribe', _activeChartSubscription);
    }
  }

  /// Unsubscribe from TradingView-style Lightweight Chart live streaming ticks
  void unsubscribeChart({String? symbol, String? interval}) {
    _activeChartSubscription = null;
    _onChartReconnect = null;
    final bool isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest && _socket?.connected == true) {
      _socket?.emit('chart:unsubscribe', {
        if (symbol != null) 'symbol': symbol,
        if (interval != null) 'interval': interval,
      });
    }
  }

  /// Add real-time listener for incoming chart forming candle ticks
  void addChartTickListener(void Function(Map<String, dynamic>) listener) {
    _chartTickListeners.add(listener);
  }

  /// Remove chart tick listener
  void removeChartTickListener(void Function(Map<String, dynamic>) listener) {
    _chartTickListeners.remove(listener);
  }

  /// Update socket auth credentials and reconnect to join user channel
  void updateAuthToken(String? token) {
    _authToken = token;
    final bool isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) return;

    if (_socket != null) {
      if (token != null && token.isNotEmpty) {
        _socket?.io.options?['auth'] = {'token': token};
      } else {
        _socket?.io.options?.remove('auth');
      }
      if (_socket?.connected == true) {
        _socket?.disconnect().connect();
      } else {
        _socket?.connect();
      }
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

          // Keep live candle formation active even on HTTP fallback / during socket reconnect
          if (_activeChartSubscription != null && _chartTickListeners.isNotEmpty) {
            final activeSym = _activeChartSubscription!['symbol'];
            final activeInterval = _activeChartSubscription!['interval'];
            if (activeSym != null) {
              final activeQuote = updated[activeSym];
              if (activeQuote != null && activeQuote.price > 0) {
                final intervalSec = _intervalToSeconds(activeInterval);
                final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                final bucketTime = (nowSec ~/ intervalSec) * intervalSec;
                final tickPayload = {
                  'symbol': activeSym,
                  'interval': activeInterval,
                  'time': bucketTime,
                  'open': activeQuote.price,
                  'high': activeQuote.high > 0 ? activeQuote.high : activeQuote.price,
                  'low': activeQuote.low > 0 ? activeQuote.low : activeQuote.price,
                  'close': activeQuote.price,
                  'delayed': activeQuote.status == 'DELAYED',
                };
                for (final listener in List.of(_chartTickListeners)) {
                  listener(tickPayload);
                }
              }
            }
          }
        }
      }
    } catch (_) {
      // Transient error, next second tick will retry
    } finally {
      _isFetching = false;
    }
  }

  int _intervalToSeconds(dynamic interval) {
    if (interval == null) return 900;
    final str = interval.toString().toLowerCase();
    if (str.endsWith('m') && !str.endsWith('mo')) {
      final m = int.tryParse(str.replaceAll('m', '')) ?? 15;
      return m * 60;
    }
    if (str.endsWith('h')) {
      final h = int.tryParse(str.replaceAll('h', '')) ?? 1;
      return h * 3600;
    }
    if (str.endsWith('d')) {
      final d = int.tryParse(str.replaceAll('d', '')) ?? 1;
      return d * 86400;
    }
    if (str.endsWith('w')) {
      final w = int.tryParse(str.replaceAll('w', '')) ?? 1;
      return w * 604800;
    }
    return 900;
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
