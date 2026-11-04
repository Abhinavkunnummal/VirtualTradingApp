import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Global layout overflow assertion guard in debug mode
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (details.toString().contains('overflowed by')) {
      debugPrint('🚨 [LAYOUT OVERFLOW DETECTED]: ${details.summary}');
      assert(false, 'RenderFlex overflow detected in debug mode: ${details.summary}');
    }
  };

  // Set system UI overlay style to dark terminal ergonomics
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF101419),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: TradeVerseApp(),
    ),
  );
}

class TradeVerseApp extends ConsumerWidget {
  const TradeVerseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'TradeVerse AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
