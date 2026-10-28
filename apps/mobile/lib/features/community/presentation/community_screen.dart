import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../ai/presentation/providers/ai_provider.dart';
import '../domain/community_models.dart';
import 'providers/community_provider.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  String _selectedSentiment = 'BULLISH';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _showComposeSheet(BuildContext context, String currentRoom) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Share Paper Setup or Idea', style: AppTypography.headlineSm),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Share your analysis, chart technicals, or simulated trade rationale...',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Sentiment:', style: AppTypography.labelSm),
                  const SizedBox(width: 8),
                  ...['BULLISH', 'BEARISH', 'NEUTRAL'].map((sentiment) {
                    final isSelected = _selectedSentiment == sentiment;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(sentiment, style: AppTypography.labelSm.copyWith(fontSize: 10)),
                        selected: isSelected,
                        selectedColor: sentiment == 'BULLISH'
                            ? AppColors.secondaryContainer
                            : sentiment == 'BEARISH'
                                ? AppColors.tertiaryContainer
                                : AppColors.surfaceHighest,
                        onSelected: (val) {
                          if (val) setSheetState(() => _selectedSentiment = sentiment);
                        },
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBrand,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final text = _messageController.text.trim();
                    if (text.isNotEmpty) {
                      await ref.read(postMessageProvider).postMessage(
                            roomId: currentRoom,
                            content: text,
                            sentiment: _selectedSentiment,
                          );
                      _messageController.clear();
                      if (context.mounted) Navigator.of(ctx).pop();
                    }
                  },
                  child: Text('Post to Channel', style: AppTypography.labelMd.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoom = ref.watch(selectedRoomIdProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Community & Social Feed', style: AppTypography.headlineSm),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryBrand,
          indicatorWeight: 2.5,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.outline,
          labelStyle: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Trading Floor Rooms'),
            Tab(text: 'AI Assistant & News'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primaryBrand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit, size: 18),
              label: Text('Share Setup', style: AppTypography.labelMd.copyWith(color: Colors.white)),
              onPressed: () => _showComposeSheet(context, selectedRoom),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCommunityFloor(context),
          _buildAiAssistantTab(context),
        ],
      ),
    );
  }

  Widget _buildCommunityFloor(BuildContext context) {
    final roomsAsync = ref.watch(communityRoomsProvider);
    final selectedRoom = ref.watch(selectedRoomIdProvider);
    final messagesAsync = ref.watch(roomMessagesProvider(selectedRoom));

    return Column(
      children: [
        // Horizontal Room Chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.surfaceLowest,
          child: roomsAsync.when(
            data: (rooms) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: rooms.map((r) {
                  final isSelected = r.roomId == selectedRoom;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text('${r.name} (${r.memberCount})'),
                      labelStyle: AppTypography.labelSm.copyWith(
                        color: isSelected ? Colors.white : AppColors.onSurface,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: AppColors.surfaceContainer,
                      selectedColor: AppColors.primaryBrand,
                      checkmarkColor: Colors.white,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      onSelected: (val) {
                        ref.read(selectedRoomIdProvider.notifier).state = r.roomId;
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            loading: () => const SizedBox(height: 36, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),

        // Messages Stream
        Expanded(
          child: messagesAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Text('No messages yet in this room. Be the first to share!', style: AppTypography.bodyMd),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.refresh(roomMessagesProvider(selectedRoom)),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageCard(context, msg);
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Failed to load messages: $err', style: AppTypography.bodyMd)),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageCard(BuildContext context, CommunityMessageModel msg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
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
                    radius: 14,
                    backgroundColor: AppColors.primaryBrand.withOpacity(0.2),
                    child: Text(
                      msg.authorName.isNotEmpty ? msg.authorName[0].toUpperCase() : 'T',
                      style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(msg.authorName, style: AppTypography.headlineSm.copyWith(fontSize: 13)),
                  const SizedBox(width: 6),
                  if (msg.sentiment != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: msg.sentiment == 'BULLISH'
                            ? AppColors.secondaryContainer.withOpacity(0.2)
                            : AppColors.tertiaryContainer.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        msg.sentiment!,
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 9,
                          color: msg.sentiment == 'BULLISH' ? AppColors.secondary : AppColors.tertiary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              Text(msg.createdAt, style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          Text(msg.content, style: AppTypography.bodyMd),
          if (msg.tradeTag != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                msg.tradeTag!,
                style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 10),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.thumb_up_alt_outlined, size: 14, color: AppColors.outline),
              const SizedBox(width: 4),
              Text('${msg.likesCount}', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiAssistantTab(BuildContext context) {
    final selectedPrompt = ref.watch(selectedAiPromptProvider);
    final explanationAsync = ref.watch(aiExplanationProvider(selectedPrompt));
    final portfolioReviewAsync = ref.watch(aiPortfolioReviewProvider);
    final newsAsync = ref.watch(aiNewsProvider);

    final suggestedPrompts = [
      'RSI Momentum',
      'Stop-Loss Order',
      'Bullish Engulfing',
      'MIS Intraday Leverage',
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // AI Suggested Concept Prompts
        Text('Ask TradeVerse AI Assistant', style: AppTypography.headlineSm),
        const SizedBox(height: 4),
        Text('Instant educational explanations with transparent scenario modeling.', style: AppTypography.bodyMd),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestedPrompts.map((p) {
            final isSelected = p == selectedPrompt;
            return ChoiceChip(
              label: Text(p),
              selected: isSelected,
              selectedColor: AppColors.primaryBrand.withOpacity(0.2),
              labelStyle: AppTypography.labelSm.copyWith(
                color: isSelected ? AppColors.primary : AppColors.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) => ref.read(selectedAiPromptProvider.notifier).state = p,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // AI Explanation Card
        explanationAsync.when(
          data: (exp) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBrand.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(exp.concept, style: AppTypography.headlineSm.copyWith(fontSize: 16)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('AI-GENERATED', style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.outline)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(exp.simpleExplanation, style: AppTypography.bodyMd),
                const SizedBox(height: 12),
                Text('Key Takeaways:', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...exp.keyTakeaways.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: AppColors.primary)),
                          Expanded(child: Text(t, style: AppTypography.bodyMd.copyWith(fontSize: 12))),
                        ],
                      ),
                    )),
                if (exp.bullishScenario != null) ...[
                  const SizedBox(height: 8),
                  Text('Bullish Scenario: ${exp.bullishScenario}',
                      style: AppTypography.bodyMd.copyWith(fontSize: 11, color: AppColors.secondary)),
                ],
                if (exp.bearishScenario != null) ...[
                  const SizedBox(height: 4),
                  Text('Bearish Scenario: ${exp.bearishScenario}',
                      style: AppTypography.bodyMd.copyWith(fontSize: 11, color: AppColors.tertiary)),
                ],
                const Divider(color: AppColors.borderSubtle, height: 18),
                Text(exp.disclaimer, style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 10)),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Error loading explanation: $err', style: AppTypography.bodyMd),
        ),
        const SizedBox(height: 20),

        // Portfolio AI Health Check Card
        Text('Portfolio Risk & Concentration Review', style: AppTypography.headlineSm),
        const SizedBox(height: 8),
        portfolioReviewAsync.when(
          data: (review) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Risk Profile: ${review.volatilityAssessment}', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: review.isConcentrated ? AppColors.tertiaryContainer.withOpacity(0.2) : AppColors.secondaryContainer.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        review.isConcentrated ? 'CONCENTRATED' : 'BALANCED',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 10,
                          color: review.isConcentrated ? AppColors.tertiary : AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Top Holding: ${review.topAsset} (${review.topAssetWeight}% of portfolio)', style: AppTypography.bodyMd),
                const SizedBox(height: 8),
                ...review.recommendations.map((rec) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.shield_outlined, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(child: Text(rec, style: AppTypography.labelSm.copyWith(fontSize: 11))),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 20),

        // Market News Pulse
        Text('Curated Market News Pulse', style: AppTypography.headlineSm),
        const SizedBox(height: 8),
        newsAsync.when(
          data: (news) => Column(
            children: news.map((article) {
              final isBullish = article.sentiment == 'BULLISH';
              final isBearish = article.sentiment == 'BEARISH';
              final color = isBullish ? AppColors.secondary : (isBearish ? AppColors.tertiary : AppColors.outline);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(article.sentiment, style: AppTypography.labelSm.copyWith(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                        Text(article.source, style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(article.title, style: AppTypography.headlineSm.copyWith(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(article.summary, style: AppTypography.bodyMd.copyWith(fontSize: 12)),
                  ],
                ),
              );
            }).toList(),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
