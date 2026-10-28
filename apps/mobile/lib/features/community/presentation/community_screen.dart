import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final posts = [
      {
        'author': 'Vikram Mehra',
        'badge': 'Top 1% Trader',
        'time': '12m ago',
        'title': 'RELIANCE Breakout Setup above ₹2,950',
        'content': 'Closed above 20 EMA on 1H chart with expanding volume. Paper long initiated with target ₹3,020 and invalidation at ₹2,925.',
        'tradeTag': 'PAPER BUY • RELIANCE',
        'likes': 42,
        'comments': 9,
      },
      {
        'author': 'Priya Sen',
        'badge': 'Quant Specialist',
        'time': '45m ago',
        'title': 'NIFTY 50 Expiry Multi-Leg Iron Condor Simulation',
        'content': 'Testing short volatility regime for tomorrow. Delta neutral setup yielding 1:1.8 risk reward with 74% win probability in backtest.',
        'tradeTag': 'PAPER SPREAD • NIFTY',
        'likes': 88,
        'comments': 23,
      },
      {
        'author': 'Siddharth Rao',
        'badge': 'Algo Builder',
        'time': '2h ago',
        'title': 'BTC/USD 15m Momentum Bot 7-Day Performance',
        'content': 'Virtual account achieved +14.2% return over 120 simulated fills with max drawdown limited to 2.8%. PineScript rule engine shared below.',
        'tradeTag': 'ALGO BOT • BTC/USD',
        'likes': 134,
        'comments': 31,
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Community & Social Feed', style: AppTypography.headlineSm),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Leaderboard: Top Simulated Performers')),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryBrand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit, size: 18),
        label: Text('Share Setup', style: AppTypography.labelMd.copyWith(color: Colors.white)),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post discussion setup or verified paper execution')),
          );
        },
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Active Discussion Channels
          Text('Live Trading Floor Rooms', style: AppTypography.labelSm),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildRoomChip(context, 'Nifty Options Desk', '1.2k online', true),
                _buildRoomChip(context, 'Crypto 24/7 Floor', '840 online', false),
                _buildRoomChip(context, 'MCX Gold & Crude', '390 online', false),
                _buildRoomChip(context, 'Quant & PineScript IDE', '520 online', false),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Community Feed Stream
          Text('Verified Trader Ideas', style: AppTypography.labelSm),
          const SizedBox(height: 8),
          ...posts.map((p) => _buildPostCard(context, p)),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildRoomChip(BuildContext context, String title, String count, bool isFirst) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Entering live chat room: $title')),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isFirst ? AppColors.primaryBrand.withOpacity(0.18) : AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isFirst ? AppColors.primaryBrand : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.labelSm.copyWith(
                  color: isFirst ? AppColors.primary : AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '($count)',
                style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, Map<String, dynamic> post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primaryContainer.withOpacity(0.3),
                    child: Text(
                      (post['author'] as String)[0],
                      style: AppTypography.labelSm.copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post['author'] as String, style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w600)),
                      Text(post['badge'] as String, style: AppTypography.labelSm.copyWith(fontSize: 10, color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
              Text(post['time'] as String, style: AppTypography.labelSm.copyWith(fontSize: 10)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
            ),
            child: Text(
              post['tradeTag'] as String,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(post['title'] as String, style: AppTypography.headlineSm.copyWith(fontSize: 15)),
          const SizedBox(height: 4),
          Text(post['content'] as String, style: AppTypography.bodyMd),
          const SizedBox(height: 12),
          const Divider(color: AppColors.borderSubtle),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_border, size: 16, color: AppColors.outline),
                  const SizedBox(width: 4),
                  Text('${post['likes']}', style: AppTypography.labelSm),
                  const SizedBox(width: 16),
                  const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.outline),
                  const SizedBox(width: 4),
                  Text('${post['comments']}', style: AppTypography.labelSm),
                ],
              ),
              const Icon(Icons.share_outlined, size: 16, color: AppColors.outline),
            ],
          ),
        ],
      ),
    );
  }
}
