import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/assessment/rank_rules.dart';
import 'package:poolcoachai/domain/rank.dart';

/// Sáu luật đổi hạng — spec mục 4.2, mỗi luật ít nhất một test.
void main() {
  final t0 = DateTime(2026, 10, 14, 9);
  final t1 = DateTime(2026, 10, 30, 9);
  final answers = QuestionnaireAnswers([2, 1, 3, 2, 1, 0, 1, 1]);

  PlayerRank ranked(Rank rank, RankSource source,
          {String? testId, int? buScore, Rank? warning, String? warningTestId}) =>
      PlayerRank(
        rank: rank,
        source: source,
        testId: testId ?? (source == RankSource.verified ? 't-cu' : null),
        buScore: buScore ?? (source == RankSource.verified ? 100 : null),
        warningRank: warning,
        warningTestId: warningTestId,
        answers: answers,
        onboardingState: OnboardingState.done,
        updatedAt: t0,
      );

  group('QuestionnaireAnswers', () {
    test('cần đúng 8 câu, mỗi câu trong số lựa chọn của nó', () {
      expect(() => QuestionnaireAnswers([0, 0, 0]), throwsArgumentError);
      expect(() => QuestionnaireAnswers([7, 0, 0, 0, 0, 0, 0, 0]), throwsRangeError,
          reason: 'Q1 chỉ có 7 lựa chọn (0…6)');
    });

    test('ghi ra JSON rồi đọc lại vẫn y nguyên', () {
      expect(QuestionnaireAnswers.fromJson(answers.toJson()), answers);
      expect(answers.of(5), 1);
    });
  });

  group('luật 1: bộ câu hỏi', () {
    test('chấp nhận hạng gợi ý thì nguồn là ước lượng', () {
      final r = rankFromQuestionnaire(null,
          chosen: Rank.h, suggested: Rank.h, answers: answers, now: t0);
      expect(r.rank, Rank.h);
      expect(r.source, RankSource.estimated);
      expect(r.onboardingState, OnboardingState.done);
      expect(r.answers, answers);
    });

    test('chọn hạng khác gợi ý thì nguồn là tự khai', () {
      final r = rankFromQuestionnaire(null,
          chosen: Rank.f, suggested: Rank.h, answers: answers, now: t0);
      expect(r.source, RankSource.selfDeclared);
    });

    test('chọn PRO luôn là tự khai', () {
      final r = rankFromQuestionnaire(null,
          chosen: Rank.pro, suggested: Rank.b, answers: answers, now: t0);
      expect(r.rank, Rank.pro);
      expect(r.source, RankSource.selfDeclared);
    });

    test('làm lại được khi hạng chưa kiểm chứng', () {
      final cur = ranked(Rank.g, RankSource.estimated);
      expect(canUseQuestionnaire(cur), isTrue);
      final r = rankFromQuestionnaire(cur,
          chosen: Rank.f, suggested: Rank.f, answers: answers, now: t1);
      expect(r.rank, Rank.f);
      expect(r.updatedAt, t1);
    });

    test('hạng đã kiểm chứng thì khoá bộ câu hỏi, kể cả tự khai PRO', () {
      final cur = ranked(Rank.d, RankSource.verified);
      expect(canUseQuestionnaire(cur), isFalse);
      expect(
        () => rankFromQuestionnaire(cur,
            chosen: Rank.pro, suggested: Rank.d, answers: answers, now: t1),
        throwsStateError,
      );
    });

    test('bộ câu hỏi không bao giờ gợi ý A hay PRO', () {
      expect(
        () => rankFromQuestionnaire(null,
            chosen: Rank.a, suggested: Rank.a, answers: answers, now: t0),
        throwsArgumentError,
      );
    });

    // D11 của kế hoạch: cảnh báo chỉ còn nghĩa khi hạng mới vẫn cao hơn nó.
    test('làm lại bộ câu hỏi: giữ cảnh báo nếu hạng mới vẫn cao hơn, bỏ nếu không', () {
      final warned = ranked(Rank.e, RankSource.estimated,
          warning: Rank.g, warningTestId: 't9');
      final higher = rankFromQuestionnaire(warned,
          chosen: Rank.f, suggested: Rank.f, answers: answers, now: t1);
      expect(higher.warningRank, Rank.g);
      expect(higher.warningTestId, 't9');
      final same = rankFromQuestionnaire(warned,
          chosen: Rank.g, suggested: Rank.g, answers: answers, now: t1);
      expect(same.warningRank, isNull);
      expect(same.warningTestId, isNull);
    });
  });

  group('Để sau', () {
    test('chưa có gì thì thành bỏ qua, không có hạng', () {
      final r = rankAfterSkip(null, t0);
      expect(r.onboardingState, OnboardingState.skipped);
      expect(r.rank, isNull);
      expect(r.source, isNull);
    });

    test('đã có hạng mà bấm Để sau khi làm lại thì không mất gì', () {
      final cur = ranked(Rank.g, RankSource.estimated);
      expect(identical(rankAfterSkip(cur, t1), cur), isTrue);
    });
  });

  group('luật 2–6: kết quả bài kiểm tra BU', () {
    test('luật 2: cao hơn thì lên hạng, kể cả nhảy nhiều hạng, thành đã kiểm chứng', () {
      final cur = ranked(Rank.h, RankSource.estimated);
      final r = applyTestResult(cur, result: Rank.e, buScore: 112, testId: 't2', now: t1);
      expect(r.outcome, RankOutcome.promoted);
      expect(r.rank.rank, Rank.e);
      expect(r.rank.source, RankSource.verified);
      expect(r.rank.buScore, 112);
      expect(r.rank.testId, 't2');
      expect(r.rank.answers, answers, reason: 'câu trả lời vẫn giữ để truy vết');
    });

    test('luật 3: bằng thì giữ hạng, thành đã kiểm chứng', () {
      final cur = ranked(Rank.g, RankSource.selfDeclared);
      final r = applyTestResult(cur, result: Rank.g, buScore: 80, testId: 't2', now: t1);
      expect(r.outcome, RankOutcome.confirmed);
      expect(r.rank.rank, Rank.g);
      expect(r.rank.source, RankSource.verified);
    });

    test('luật 4: thấp hơn thì giữ hạng và nguồn, đặt cảnh báo', () {
      final cur = ranked(Rank.e, RankSource.verified, testId: 't1', buScore: 115);
      final r = applyTestResult(cur, result: Rank.g, buScore: 80, testId: 't2', now: t1);
      expect(r.outcome, RankOutcome.warned);
      expect(r.rank.rank, Rank.e);
      expect(r.rank.source, RankSource.verified);
      expect(r.rank.testId, 't1', reason: 'lần kiểm chứng hạng vẫn là lần cũ');
      expect(r.rank.buScore, 115);
      expect(r.rank.warningRank, Rank.g);
      expect(r.rank.warningTestId, 't2');
    });

    test('luật 4: lần sau bằng hoặc cao hơn thì xoá cảnh báo', () {
      final warned = ranked(Rank.e, RankSource.verified,
          testId: 't1', buScore: 115, warning: Rank.g, warningTestId: 't2');
      final r = applyTestResult(warned, result: Rank.e, buScore: 118, testId: 't3', now: t1);
      expect(r.rank.warningRank, isNull);
      expect(r.rank.warningTestId, isNull);
      expect(r.rank.testId, 't3');
    });

    test('luật 5: BU không bao giờ ra PRO; người tự khai PRO ra A thì bị cảnh báo', () {
      expect(
        () => applyTestResult(null, result: Rank.pro, buScore: 200, testId: 't', now: t1),
        throwsArgumentError,
      );
      final pro = ranked(Rank.pro, RankSource.selfDeclared);
      final r = applyTestResult(pro, result: Rank.a, buScore: 190, testId: 't2', now: t1);
      expect(r.outcome, RankOutcome.warned);
      expect(r.rank.rank, Rank.pro);
      expect(r.rank.source, RankSource.selfDeclared);
      expect(r.rank.warningRank, Rank.a);
    });

    test('luật 6: chưa có hạng (đã bỏ qua) thì nhận hạng từ kết quả', () {
      final skipped = rankAfterSkip(null, t0);
      final r = applyTestResult(skipped, result: Rank.h, buScore: 50, testId: 't1', now: t1);
      expect(r.outcome, RankOutcome.firstRank);
      expect(r.rank.rank, Rank.h);
      expect(r.rank.source, RankSource.verified);
      expect(r.rank.onboardingState, OnboardingState.skipped,
          reason: 'trạng thái onboarding không bị viết lại');
      final none = applyTestResult(null, result: Rank.k, buScore: 5, testId: 't1', now: t1);
      expect(none.outcome, RankOutcome.firstRank);
      expect(none.rank.onboardingState, OnboardingState.done);
    });

    test('app không bao giờ tự hạ hạng: mọi kết quả thấp hơn đều giữ hạng', () {
      for (final current in Rank.values) {
        for (final result in Rank.values.where((r) => r != Rank.pro)) {
          final cur = ranked(current, RankSource.selfDeclared);
          final r = applyTestResult(cur, result: result, buScore: 1, testId: 't', now: t1);
          expect(r.rank.rank!.index, greaterThanOrEqualTo(current.index),
              reason: '$current → $result');
        }
      }
    });
  });
}
