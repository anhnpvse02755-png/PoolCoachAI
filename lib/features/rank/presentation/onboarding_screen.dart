import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_rank_badge.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/assessment/rank_rules.dart';
import 'package:poolcoachai/domain/rank.dart';

enum _Step { intro, questions, suggestion, choose }

/// Bộ câu hỏi xác định hạng — spec mục 7.2. Màn nào cũng có *Để sau*.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.intro;
  int _question = 1;
  final _choices = List<int?>.filled(questionOptionCounts.length, null);
  Rank? _suggested;
  bool _saving = false;

  QuestionnaireAnswers get _answers => QuestionnaireAnswers([for (final c in _choices) c!]);

  /// Mở từ màn Hạng (làm lại) thì quay về đó; bị chuyển tới sau đăng nhập
  /// thì không có gì để quay lại, nên về Trang chủ.
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    await ref.read(assessmentRepositoryProvider)?.skipOnboarding();
    if (mounted) _leave();
  }

  Future<void> _save(Rank chosen) async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref
        .read(assessmentRepositoryProvider)!
        .saveQuestionnaire(chosen: chosen, suggested: _suggested!, answers: _answers);
    if (mounted) _leave();
  }

  void _next() {
    if (_question < questionOptionCounts.length) {
      setState(() => _question++);
      return;
    }
    setState(() {
      _suggested = suggestRank(_answers);
      _step = _Step.suggestion;
    });
  }

  void _back() => setState(() {
        if (_question > 1) {
          _question--;
        } else {
          _step = _Step.intro;
        }
      });

  @override
  Widget build(BuildContext context) {
    final rank = ref.watch(playerRankProvider);
    final locked = rank.hasValue && !canUseQuestionnaire(rank.value);
    return Scaffold(
      appBar: AppBar(
        title: const Text(Vi.onboardingTitle),
        actions: [
          if (!locked)
            TextButton(
              onPressed: _saving ? null : _skip,
              child: const Text(Vi.onboardingLater),
            ),
        ],
      ),
      body: SafeArea(
        child: locked
            ? _padded([
                const Text(Vi.onboardingLocked),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(onPressed: _leave, child: const Text(Vi.onboardingBack)),
              ])
            : switch (_step) {
                _Step.intro => _intro(context),
                _Step.questions => _questionPage(context),
                _Step.suggestion => _suggestion(context),
                _Step.choose => _choose(context),
              },
      ),
    );
  }

  Widget _padded(List<Widget> children) => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: children,
      );

  Widget _intro(BuildContext context) => _padded([
        Text(Vi.onboardingIntroTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        const Text(Vi.onboardingIntroBody),
        const SizedBox(height: AppSpacing.md),
        const Text(Vi.rankDisclaimer),
        const SizedBox(height: AppSpacing.xxl),
        FilledButton(
          onPressed: () => setState(() => _step = _Step.questions),
          child: const Text(Vi.onboardingStart),
        ),
      ]);

  Widget _questionPage(BuildContext context) {
    final chosen = _choices[_question - 1];
    // Nút Quay lại / Tiếp nằm ngoài danh sách: câu nhiều lựa chọn (Q3 có 9)
    // trên màn hình thấp vẫn thấy nút mà không phải cuộn.
    return Column(
      children: [
        Expanded(
          child: _padded([
            Text(Vi.onboardingQuestionCounter(_question),
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(Vi.rankQuestion(_question), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            for (final (i, option) in Vi.rankQuestionOptions(_question).indexed)
              ListTile(
                leading:
                    Icon(chosen == i ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title: Text(option),
                selected: chosen == i,
                onTap: () => setState(() => _choices[_question - 1] = i),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              OutlinedButton(onPressed: _back, child: const Text(Vi.onboardingBack)),
              const Spacer(),
              FilledButton(
                onPressed: chosen == null ? null : _next,
                child: const Text(Vi.onboardingNext),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _suggestion(BuildContext context) {
    final s = _suggested!;
    return _padded([
      Text(Vi.onboardingSuggestTitle, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.lg),
      Align(alignment: Alignment.centerLeft, child: PcRankBadge(rank: s, showWord: true)),
      const SizedBox(height: AppSpacing.md),
      Text(Vi.rankDescription(s)),
      const SizedBox(height: AppSpacing.md),
      Text(Vi.rankDisclaimer, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: AppSpacing.xxl),
      FilledButton(
        onPressed: _saving ? null : () => _save(s),
        child: const Text(Vi.onboardingConfirm),
      ),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton(
        onPressed: _saving ? null : () => setState(() => _step = _Step.choose),
        child: const Text(Vi.onboardingChooseOther),
      ),
    ]);
  }

  Widget _choose(BuildContext context) => _padded([
        Text(Vi.onboardingChooseTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        for (final r in Rank.values)
          ListTile(
            leading: PcRankBadge(rank: r),
            title: Text(Vi.rankDescription(r)),
            subtitle: Text(Vi.rankGroupName(r.group)),
            onTap: _saving ? null : () => _save(r),
          ),
      ]);
}
