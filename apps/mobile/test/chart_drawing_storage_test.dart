import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tradeverse_mobile/features/trade/presentation/services/chart_drawing_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('ChartDrawingStorage Unit Tests', () {
    test('saveDrawings and loadDrawings persist per canonical symbol', () async {
      final storage = ChartDrawingStorage();
      final sampleDrawings = [
        {
          'id': 'd_1',
          'type': 'trend_line',
          'points': [
            {'time': 1700000000, 'price': 100.0},
            {'time': 1700000060, 'price': 105.0},
          ],
          'color': '#2962ff',
        },
      ];

      // Save using slashed symbol 'BTC/USDT'
      await storage.saveDrawings('BTC/USDT', sampleDrawings);

      // Load using lowercase clean symbol 'btcusdt'
      final loaded = await storage.loadDrawings('btcusdt');
      expect(loaded.length, equals(1));
      expect(loaded.first['type'], equals('trend_line'));
      expect(loaded.first['id'], equals('d_1'));
    });

    test('clearDrawings removes drawings for the symbol', () async {
      final storage = ChartDrawingStorage();
      final sampleDrawings = [
        {
          'id': 'hl_1',
          'type': 'horizontal_line',
          'points': [
            {'time': 1700000000, 'price': 2500.0},
          ],
        },
      ];

      await storage.saveDrawings('RELIANCE', sampleDrawings);
      var loaded = await storage.loadDrawings('RELIANCE');
      expect(loaded.length, equals(1));

      await storage.clearDrawings('RELIANCE');
      loaded = await storage.loadDrawings('RELIANCE');
      expect(loaded.isEmpty, isTrue);
    });

    test('loadDrawings returns empty list when key is absent', () async {
      final storage = ChartDrawingStorage();
      final loaded = await storage.loadDrawings('NON_EXISTENT');
      expect(loaded, isEmpty);
    });
  });
}
