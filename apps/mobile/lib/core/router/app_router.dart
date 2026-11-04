import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/shell/app_shell.dart';
import '../../features/shell/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/home/presentation/home_dashboard_screen.dart';
import '../../features/markets/presentation/markets_screen.dart';
import '../../features/trade/presentation/trade_screen.dart';
import '../../features/trade/presentation/trading_view_chart_screen.dart';
import '../../features/trade/presentation/orders_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/portfolio/presentation/portfolio_screen.dart';
import '../../features/learn/presentation/learn_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final isSplash = state.matchedLocation == '/splash';
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      // While checking auth status at launch, stay on splash screen
      if (authState.status == AuthStatus.initial || authState.status == AuthStatus.loading) {
        return isSplash ? null : '/splash';
      }

      final hasAccess = authState.isAuthenticated || authState.isDemoMode;

      if (!hasAccess) {
        return (isLoggingIn || isRegistering) ? null : '/login';
      }

      if (hasAccess && (isLoggingIn || isRegistering || isSplash)) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/learn',
        name: 'learn',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => const MaterialPage(
          child: LearnScreen(),
        ),
      ),
      GoRoute(
        path: '/tradingview-pro',
        name: 'tradingview_pro',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => const MaterialPage(
          child: TradingViewChartScreen(),
        ),
      ),
      GoRoute(
        path: '/orders',
        name: 'orders',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => const MaterialPage(
          child: OrdersScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Tab 0: Home Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomeDashboardScreen(),
                ),
              ),
            ],
          ),
          // Tab 1: Markets & Discovery
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/markets',
                name: 'markets',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: MarketsScreen(),
                ),
              ),
            ],
          ),
          // Tab 2: Trade Ticket & Execution
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trade',
                name: 'trade',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: TradeScreen(),
                ),
              ),
            ],
          ),
          // Tab 3: Community & Social Feed
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                name: 'community',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: CommunityScreen(),
                ),
              ),
            ],
          ),
          // Tab 4: Portfolio & Analytics
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/portfolio',
                name: 'portfolio',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: PortfolioScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
