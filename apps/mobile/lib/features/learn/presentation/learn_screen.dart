import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/core/theme/app_colors.dart';
import 'package:tradeverse_mobile/core/theme/app_typography.dart';
import 'package:tradeverse_mobile/features/learn/domain/learn_models.dart';
import 'package:tradeverse_mobile/features/learn/presentation/providers/learn_provider.dart';
import 'package:tradeverse_mobile/shared/widgets/loading_state_widget.dart';
import 'package:tradeverse_mobile/shared/widgets/error_state_widget.dart';

class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  void _openModuleDetail(LearningModuleModel module) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: ListView(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBrand.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'MODULE ${module.order} • ${module.category}',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(module.title, style: AppTypography.headlineSm),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.outline),
                  const SizedBox(width: 4),
                  Text('${module.readTimeMinutes} min read', style: AppTypography.labelSm),
                ],
              ),
              const SizedBox(height: 14),
              Text(module.description, style: AppTypography.bodyMd),
              const SizedBox(height: 16),

              // Objectives
              Text('Learning Objectives', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...module.learningObjectives.map((obj) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(obj, style: AppTypography.bodyMd)),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),

              // Content Sections
              ...module.contentSections.map((sec) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sec.heading, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(sec.body, style: AppTypography.bodyMd),
                        ],
                      ),
                    ),
                  )),

              // Key Takeaways
              Text('Key Takeaways', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...module.keyTakeaways.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $t', style: AppTypography.bodyMd),
                  )),
              const SizedBox(height: 24),

              // Quiz Button
              if (module.quizzes.isNotEmpty)
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.quiz_outlined, size: 18),
                    label: const Text('Take Module Quiz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBrand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _openQuizModal(module);
                    },
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _openQuizModal(LearningModuleModel module) {
    if (module.quizzes.isEmpty) return;
    final quiz = module.quizzes.first;

    int? selectedOption;
    bool submitted = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isCorrect = submitted && selectedOption == quiz.correctIndex;

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Quiz: ${module.title}',
                        style: AppTypography.headlineSm.copyWith(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(quiz.question, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                ...List.generate(quiz.options.length, (idx) {
                  final isSelected = selectedOption == idx;
                  Color tileColor = AppColors.surfaceLowest;
                  Color borderColor = AppColors.borderSubtle;

                  if (submitted) {
                    if (idx == quiz.correctIndex) {
                      tileColor = AppColors.secondary.withOpacity(0.15);
                      borderColor = AppColors.secondary;
                    } else if (isSelected) {
                      tileColor = AppColors.error.withOpacity(0.15);
                      borderColor = AppColors.error;
                    }
                  } else if (isSelected) {
                    borderColor = AppColors.primaryBrand;
                    tileColor = AppColors.primaryBrand.withOpacity(0.1);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: submitted
                          ? null
                          : () {
                              setModalState(() => selectedOption = idx);
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: tileColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Text(
                              String.fromCharCode(65 + idx),
                              style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(quiz.options[idx], style: AppTypography.bodyMd)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                if (submitted) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCorrect ? AppColors.secondary.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isCorrect ? AppColors.secondary : AppColors.error),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCorrect ? Icons.check_circle : Icons.cancel,
                              size: 18,
                              color: isCorrect ? AppColors.secondary : AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isCorrect ? 'Correct! Well Done.' : 'Incorrect Answer',
                              style: AppTypography.bodyLg.copyWith(
                                color: isCorrect ? AppColors.secondary : AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(quiz.explanation, style: AppTypography.bodyMd),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBrand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: selectedOption == null
                        ? null
                        : () {
                            if (!submitted) {
                              setModalState(() => submitted = true);
                              if (selectedOption == quiz.correctIndex) {
                                final set = Set<String>.from(ref.read(completedModulesProvider));
                                set.add(module.id);
                                ref.read(completedModulesProvider.notifier).state = set;
                              }
                            } else {
                              Navigator.of(ctx).pop();
                            }
                          },
                    child: Text(submitted ? 'Finish' : 'Submit Answer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  ),
);
  }

  void _openTutorModal() {
    final queryController = TextEditingController();
    TutorResponseModel? tutorReply;
    bool isThinking = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text('AI Trading Tutor', style: AppTypography.headlineSm),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ask anything about candlesticks, order execution, indicators, or risk rules.',
                    style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: queryController,
                          decoration: InputDecoration(
                            hintText: 'e.g. How does 5x leverage work?',
                            filled: true,
                            fillColor: AppColors.surfaceLowest,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onSubmitted: (val) async {
                            if (val.trim().isEmpty) return;
                            setModalState(() => isThinking = true);
                            final reply = await ref.read(aiTutorServiceProvider).askTutor(val.trim());
                            setModalState(() {
                              isThinking = false;
                              tutorReply = reply;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: isThinking
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send, color: AppColors.primary),
                        onPressed: isThinking
                            ? null
                            : () async {
                                final text = queryController.text.trim();
                                if (text.isEmpty) return;
                                setModalState(() => isThinking = true);
                                final reply = await ref.read(aiTutorServiceProvider).askTutor(text);
                                setModalState(() {
                                  isThinking = false;
                                  tutorReply = reply;
                                });
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: tutorReply != null
                        ? ListView(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLowest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tutor Explanation',
                                      style: AppTypography.labelMd.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(tutorReply!.answer, style: AppTypography.bodyMd),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Practical Example',
                                      style: AppTypography.labelMd.copyWith(
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(tutorReply!.exampleScenario, style: AppTypography.bodyMd),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.warning),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              tutorReply!.actionableTip,
                                              style: AppTypography.labelSm.copyWith(color: AppColors.onSurface),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.school_outlined, size: 48, color: AppColors.outline),
                                const SizedBox(height: 8),
                                Text('Your AI tutor is ready.', style: AppTypography.bodyMd),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
  }

  @override
  Widget build(BuildContext context) {
    final modulesAsync = ref.watch(learningModulesProvider);
    final completed = ref.watch(completedModulesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Learn Trading with AI', style: AppTypography.headlineSm),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent),
            tooltip: 'Ask AI Tutor',
            onPressed: _openTutorModal,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryBrand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text('Ask AI Tutor'),
        onPressed: _openTutorModal,
      ),
      body: modulesAsync.when(
        data: (modules) => ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          itemCount: modules.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final mod = modules[index];
            final isDone = completed.contains(mod.id);

            return Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDone ? AppColors.secondary.withOpacity(0.5) : AppColors.borderSubtle,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                onTap: () => _openModuleDetail(mod),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDone ? AppColors.secondary.withOpacity(0.15) : AppColors.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${mod.order}',
                    style: AppTypography.labelMd.copyWith(
                      color: isDone ? AppColors.secondary : AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(mod.title, style: AppTypography.headlineSm.copyWith(fontSize: 14)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          mod.category,
                          style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.outline),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${mod.readTimeMinutes} min read', style: AppTypography.labelSm),
                    ],
                  ),
                ),
                trailing: isDone
                    ? const Icon(Icons.check_circle, color: AppColors.secondary, size: 22)
                    : const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.outline),
              ),
            );
          },
        ),
        loading: () => const LoadingStateWidget(message: 'Loading trading curriculum...'),
        error: (err, _) => ErrorStateWidget(
          title: 'Unable to Load Modules',
          message: err.toString(),
          onRetry: () => ref.refresh(learningModulesProvider),
        ),
      ),
    );
  }
}
