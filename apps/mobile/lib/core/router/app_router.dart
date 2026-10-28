import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/shell/app_shell.dart';
import '../../features/home/presentation/home_dashboard_screen.dart';
import '../../features/markets/presentation/markets_screen.dart';
import '../../features/trade/presentation/trade_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/portfolio/presentation/portfolio_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
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
