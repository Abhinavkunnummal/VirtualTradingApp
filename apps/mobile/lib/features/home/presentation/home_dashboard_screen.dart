import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeverse_mobile/core/network/live_ticker_service.dart';
import 'package:tradeverse_mobile/core/theme/app_colors.dart';
import 'package:tradeverse_mobile/core/theme/app_typography.dart';
import 'package:tradeverse_mobile/shared/widgets/demo_mode_banner.dart';
import 'package:tradeverse_mobile/shared/widgets/loading_state_widget.dart';
import 'package:tradeverse_mobile/shared/widgets/error_state_widget.dart';
import 'package:tradeverse_mobile/shared/widgets/tradeverse_logo.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/providers/portfolio_provider.dart';
import 'package:tradeverse_mobile/features/portfolio/domain/portfolio_models.dart';
import 'package:tradeverse_mobile/features/notifications/presentation/providers/notification_provider.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final portfolioAsync = ref.watch(portfolioProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top App Bar
            SliverToBoxAdapter(
              child: _buildHeader(context, ref, authState.user?.displayName),
            ),
            // Explicit Demo Mode Banner (if in demo mode)
            if (authState.isDemoMode)
              SliverToBoxAdapter(
                child: DemoModeBanner(
                  onLoginTap: () => context.go('/login'),
                ),
              ),
            // Simulation Banner
            SliverToBoxAdapter(
              child: _buildDisclaimerBanner(),
            ),
            // Virtual Portfolio Card with Loading & Error States
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: portfolioAsync.when(
                  data: (portfolio) => _buildPortfolioCard(context, portfolio),
                  loading: () => Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: const LoadingStateWidget(message: 'Calculating sandbox portfolio value...'),
                  ),
                  error: (err, _) => Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: ErrorStateWidget(
                      title: 'Portfolio Offline',
                      message: 'Using cached sandbox telemetry.',
                      onRetry: () => ref.refresh(portfolioProvider),
                    ),
                  ),
                ),
              ),
            ),
            // Quick Action Buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildQuickActions(context),
              ),
            ),
            // Ticker Stream Header & Carousel
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Simulated Ticker Stream', style: AppTypography.headlineSm),
                      ],
                    ),
                    Text('Live Feed', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildTickerStream(),
            ),
            // Market Highlights / Movers
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Trending Instruments', style: AppTypography.headlineSm),
                    GestureDetector(
                      onTap: () => context.go('/markets'),
                      child: Text('View All', style: AppTypography.labelSm.copyWith(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                _buildInstrumentTile(
                  ref: ref,
                  symbol: 'RELIANCE',
                  name: 'Reliance Industries Ltd.',
                  exchange: 'NSE',
                  price: '₹2,945.50',
                  change: '+₹18.40 (+0.63%)',
                  isPositive: true,
                  onTap: () => context.go('/trade'),
                ),
                _buildInstrumentTile(
                  ref: ref,
                  symbol: 'HDFCBANK',
                  name: 'HDFC Bank Limited',
                  exchange: 'NSE',
                  price: '₹1,720.80',
                  change: '+₹12.10 (+0.71%)',
                  isPositive: true,
                  onTap: () => context.go('/trade'),
                ),
                _buildInstrumentTile(
                  ref: ref,
                  symbol: 'TCS',
                  name: 'Tata Consultancy Services',
                  exchange: 'NSE',
                  price: '₹4,120.00',
                  change: '-₹24.50 (-0.59%)',
                  isPositive: false,
                  onTap: () => context.go('/trade'),
                ),
                _buildInstrumentTile(
                  ref: ref,
                  symbol: 'BTC/USD',
                  name: 'Bitcoin (24/7 Sandbox)',
                  exchange: 'CRYPTO',
                  price: '\$67,420.00',
                  change: '+\$2,140.00 (+3.28%)',
                  isPositive: true,
                  onTap: () => context.go('/trade'),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, String? displayName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const TradeVerseLogo(size: 36),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName ?? 'TradeVerse AI',
                    style: AppTypography.headlineSm.copyWith(fontSize: 15),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBrand.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.primaryBrand.withOpacity(0.3)),
                        ),
                        child: Text(
                          'SIMULATION',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('v2.4 Sandbox', style: AppTypography.labelSm),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.logout, size: 20, color: AppColors.outline),
                tooltip: 'Logout',
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),
              Builder(
                builder: (context) {
                  final unreadCount = ref.watch(unreadNotificationsCountProvider);
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showNotificationsSheet(context, ref),
                    child: Stack(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: const Icon(Icons.notifications_none, size: 20, color: AppColors.onSurface),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 2,
                            top: 2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryBrand,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$unreadCount',
                                style: AppTypography.labelSm.copyWith(
                                  fontSize: 8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Paper Trading Mode • Fictional Capital • No Real Money at Risk',
              style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioCard(BuildContext context, PortfolioModel portfolio) {
    final isPos = portfolio.totalPnl >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceContainer,
            AppColors.surfaceLow,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Virtual Capital (Simulated)', style: AppTypography.labelMd.copyWith(color: AppColors.outline)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 11, color: AppColors.outline),
                    const SizedBox(width: 4),
                    Text('Sandbox v2.4', style: AppTypography.labelSm.copyWith(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${portfolio.totalPortfolioValue.toStringAsFixed(2)}',
            style: AppTypography.numericTicker.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isPos ? AppColors.secondary : AppColors.tertiary).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPos ? Icons.trending_up : Icons.trending_down,
                      size: 14,
                      color: isPos ? AppColors.secondary : AppColors.tertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPos ? '+' : ''}₹${portfolio.totalPnl.toStringAsFixed(2)} (${portfolio.totalPnlPercent}%)',
                      style: AppTypography.numericTable.copyWith(
                        color: isPos ? AppColors.secondary : AppColors.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text("Today's Sim Return", style: AppTypography.labelSm),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.borderSubtle),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Virtual Cash Available', style: AppTypography.labelSm),
                    const SizedBox(height: 2),
                    Text(
                      '₹${portfolio.availableCash.toStringAsFixed(2)}',
                      style: AppTypography.numericTable.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: AppColors.borderSubtle),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invested Exposure', style: AppTypography.labelSm),
                    const SizedBox(height: 2),
                    Text(
                      '₹${portfolio.investedValue.toStringAsFixed(2)}',
                      style: AppTypography.numericTable.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _QuickActionButton(
          icon: Icons.add_circle_outline,
          label: 'Add Cash',
          onTap: () => context.go('/portfolio'),
        ),
        _QuickActionButton(
          icon: Icons.swap_horiz,
          label: 'Sim Trade',
          onTap: () => context.go('/trade'),
        ),
        _QuickActionButton(
          icon: Icons.school_outlined,
          label: 'Learn AI',
          onTap: () => context.push('/learn'),
        ),
        _QuickActionButton(
          icon: Icons.bookmark_border,
          label: 'Watchlist',
          onTap: () => context.go('/markets'),
        ),
      ],
    );
  }

  Widget _buildTickerStream() {
    final tickers = [
      {'symbol': 'NIFTY 50', 'price': '24,852.15', 'change': '+0.72%', 'isPos': true},
      {'symbol': 'SENSEX', 'price': '81,420.30', 'change': '+0.65%', 'isPos': true},
      {'symbol': 'S&P 500', 'price': '5,864.67', 'change': '+0.41%', 'isPos': true},
      {'symbol': 'BTC/USD', 'price': '\$67,420.00', 'change': '+3.28%', 'isPos': true},
      {'symbol': 'GOLD (MCX)', 'price': '₹78,450.00', 'change': '+0.55%', 'isPos': true},
    ];

    return SizedBox(
      height: 72,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tickers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final t = tickers[index];
          final isPos = t['isPos'] as bool;
          return Container(
            width: 155,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t['symbol'] as String, style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        t['price'] as String,
                        style: AppTypography.numericTable,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      t['change'] as String,
                      style: AppTypography.numericTable.copyWith(
                        color: isPos ? AppColors.secondary : AppColors.tertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstrumentTile({
    required WidgetRef ref,
    required String symbol,
    required String name,
    required String exchange,
    required String price,
    required String change,
    required bool isPositive,
    required VoidCallback onTap,
  }) {
    final live = ref.watch(liveQuoteForSymbolProvider(symbol == 'BTC/USD' ? 'BTC/USDT' : symbol));
    final isCrypto = exchange == 'CRYPTO';
    final currency = isCrypto || exchange == 'US' ? '\$' : '₹';
    final displayPrice = (live != null && live.price > 0) ? '$currency${live.price.toStringAsFixed(2)}' : price;
    final displayChange = live != null
        ? '${live.change >= 0 ? '+' : ''}$currency${live.change.toStringAsFixed(2)} (${live.changePercent.toStringAsFixed(2)}%)'
        : change;
    final itemIsPos = live != null ? (live.change >= 0) : isPositive;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Row(
          children: [
            Text(symbol, style: AppTypography.headlineSm.copyWith(fontSize: 15)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(exchange, style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.outline)),
            ),
          ],
        ),
        subtitle: Text(name, style: AppTypography.bodyMd.copyWith(fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(displayPrice, style: AppTypography.numericTable.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              displayChange,
              style: AppTypography.numericTable.copyWith(
                color: itemIsPos ? AppColors.secondary : AppColors.tertiary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final notifsAsync = ref.watch(notificationsProvider);

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications, color: AppColors.primaryBrand, size: 20),
                        const SizedBox(width: 8),
                        Text('Notifications', style: AppTypography.headlineSm),
                      ],
                    ),
                    TextButton(
                      onPressed: () => ref.read(notificationsProvider.notifier).markAllAsRead(),
                      child: Text('Mark all as read', style: AppTypography.labelSm.copyWith(color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: notifsAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.outline),
                              const SizedBox(height: 12),
                              Text('No notifications yet', style: AppTypography.bodyMd),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final n = items[index];
                          Color iconColor = AppColors.primaryBrand;
                          IconData iconData = Icons.notifications;

                          if (n.type == 'ORDER_FILL') {
                            iconColor = AppColors.secondary;
                            iconData = Icons.check_circle;
                          } else if (n.type == 'BRACKET_OCO') {
                            iconColor = AppColors.primary;
                            iconData = Icons.alt_route;
                          } else if (n.type == 'TRAILING_STOP') {
                            iconColor = AppColors.warning;
                            iconData = Icons.trending_up;
                          } else if (n.type == 'TOPUP') {
                            iconColor = AppColors.secondary;
                            iconData = Icons.account_balance_wallet;
                          } else if (n.type == 'ORDER_CANCEL') {
                            iconColor = AppColors.tertiary;
                            iconData = Icons.cancel;
                          }

                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              if (!n.read) {
                                ref.read(notificationsProvider.notifier).markAsRead(n.id);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: n.read ? AppColors.surfaceLowest : AppColors.surfaceHighest.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: n.read ? AppColors.borderSubtle : AppColors.primaryBrand.withOpacity(0.4),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(iconData, size: 20, color: iconColor),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n.title,
                                          style: AppTypography.bodyLg.copyWith(
                                            fontSize: 13,
                                            fontWeight: n.read ? FontWeight.w500 : FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          n.message,
                                          style: AppTypography.bodyMd.copyWith(
                                            fontSize: 11,
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!n.read)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(top: 4, left: 6),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryBrand,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Error loading notifications', style: AppTypography.bodyMd)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(label, style: AppTypography.labelSm.copyWith(fontSize: 10, color: AppColors.onSurface)),
          ],
        ),
      ),
    );
  }
}
