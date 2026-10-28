import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/coach/chat_filter.dart';
import 'package:poolcoachai/domain/coach/coach_recommendation.dart';
import 'package:poolcoachai/domain/coach/coach_stats.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/hints.dart';
import 'package:poolcoachai/domain/coach/reference.dart';
import 'package:poolcoachai/domain/coach/reveal.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/table_geometry/saws.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

/// Mọi dữ liệu gợi ý 1 có thể có, một mẫu mỗi loại.
const hintOnes = <HintOne>[
  HintPathBlocked(1, Pocket.bottomMiddle),
  HintTooThin(Pocket.topLeft),
  HintGhostOff(Pocket.topMiddle),
  HintScratch(Pocket.bottomRight),
  HintMissed(1, Pocket.topRight),
  HintBlocker(4),
  HintNoNext(2),
  HintPosition(2),
  HintSimpler(),
  HintShouldPot(1),
];

const hintTwos = <HintTwo>[
  Hint2Pocket(1),
  Hint2NoSpin(),
  Hint2NeedSpin(),
  Hint2Spin(),
  Hint2Stroke(),
  Hint2PowerLess(),
  Hint2PowerMore(),
  Hint2Pot(1),
  Hint2Safety(1),
];

const reasons = <RevealReason>[
  ReasonZone(CoachZone.good, 2),
  ReasonYourZone(CoachZone.hard, 2),
  ReasonYourScratch(Pocket.bottomLeft),
  ReasonYourBlocked(3),
  ReasonYourMissed(1, Pocket.bottomMiddle),
  ReasonYourNoNext(2),
  ReasonYourUnmakeable(1, Pocket.topLeft),
  ReasonNoSpin(),
  ReasonStroke(Stroke.stun, Stroke.draw),
  ReasonPower(45, 75),
];

void main() {
  test('mỗi loại gợi ý và lý do ra một câu khác nhau', () {
    expect(hintOnes.map(Vi.coachHintOne).toSet(), hasLength(hintOnes.length));
    expect(hintTwos.map(Vi.coachHintTwo).toSet(), hasLength(hintTwos.length));
    expect(reasons.map(Vi.coachReason).toSet(), hasLength(reasons.length));
    final verdicts = [
      for (final o in CoachOutcome.values)
        if (o != CoachOutcome.undecided) CoachVerdict(outcome: o),
      const CoachVerdict(outcome: CoachOutcome.better, noPlannerPot: true),
      const CoachVerdict(outcome: CoachOutcome.undecided, undecided: CoachUndecidedReason.timeout),
      const CoachVerdict(outcome: CoachOutcome.undecided, undecided: CoachUndecidedReason.potVsSafety),
    ];
    expect(verdicts.map(Vi.coachVerdict).toSet(), hasLength(verdicts.length));
  });

  test('tham số đi vào câu: số bi, lỗ, bi chắn', () {
    expect(Vi.coachHintOne(const HintBlocker(4)), contains('bi 4'));
    expect(Vi.coachHintOne(const HintBlocker(6)), contains('bi 6'));
    expect(Vi.coachHintOne(const HintScratch(Pocket.bottomRight)), contains('góc dưới phải'));
    expect(Vi.coachPrompt(3), 'Tới lượt bạn. Bi phải chạm: bi 3. Bạn đánh thế nào?');
    expect(Vi.coachTryCount(2, 3), 'Lần thử 2/3');
    expect(Vi.coachTableSummary(4, 2), 'Bàn tình huống: bi cái và 4 bi. Bi phải chạm: bi 2.');
    expect(Vi.coachRevealShot(1, Pocket.bottomMiddle, Stroke.stun, 45),
        'Bi 1 vào lỗ giữa dưới — Đánh đứng bi, lực 45%.');
  });

  test('câu áp phê của đáp án theo đúng mẫu SAWS của chủ sản phẩm', () {
    expect(
      Vi.coachRevealSpin((side: SpinSide.right, tips: 1, bhe: 70, speed: SawsSpeed.medium)),
      'Cú này cần áp phê phải 1 đầu cơ. Hãy ngắm như đánh tâm bi, '
      'bù trừ áp phê bằng 70% BHE, 30% FHE với lực trung bình.',
    );
  });

  test('thuật ngữ đã chốt', () {
    expect(Vi.coachChoiceSafety, 'Phòng thủ');
    expect(Vi.coachReason(const ReasonStroke(Stroke.stun, Stroke.draw)), contains('Đánh đứng bi'));
    expect(Vi.coachReason(const ReasonStroke(Stroke.follow, Stroke.draw)), contains('Đánh cu lê'));
    expect(Vi.coachReason(const ReasonStroke(Stroke.follow, Stroke.draw)), contains('Đánh trô bi'));
    expect(Vi.coachReason(const ReasonNoSpin()), contains('áp phê'));
    expect(Vi.coachReason(const ReasonYourScratch(Pocket.topLeft)), contains('chết cái'));
    expect(Vi.coachTopic(CoachTopic.kick), 'A băng');
    expect(Vi.coachRevealSpin((side: SpinSide.left, tips: 0.5, bhe: 60, speed: SawsSpeed.slow)),
        contains('đầu cơ'));
    expect(Vi.coachHintOne(const HintPathBlocked(1, Pocket.topLeft)), contains('bi ảo'));
  });

  test('lý do matchWeakness nêu nhóm yếu trong các trận gần đây', () {
    expect(Vi.coachRecReason(CoachTopicReason.matchWeakness, CoachTopic.position),
        'Điều bi / Vị trí đang yếu trong các trận gần đây.');
  });

  test('không có chữ cấm trong mọi câu Coach', () {
    final all = [
      ...hintOnes.map(Vi.coachHintOne),
      ...hintTwos.map(Vi.coachHintTwo),
      ...reasons.map(Vi.coachReason),
      for (final g in CoachFaultGroup.values) Vi.coachFaultGroup(g),
      for (final d in CoachDifficulty.values) Vi.coachDifficulty(d),
      for (final r in CoachTopicReason.values)
        for (final t in CoachTopic.values) Vi.coachRecReason(r, t),
      Vi.coachTopicUnsupported(SkillCategory.bank),
      Vi.coachRevealSafetyNote,
      Vi.coachRevealPotVsSafety,
      Vi.coachModelNote,
      Vi.coachSituationsBody,
    ];
    for (final line in all) {
      expect(line.toLowerCase(), isNot(contains('bi ma')), reason: line);
      expect(line.toLowerCase(), isNot(contains('lọt bi cái')), reason: line);
      expect(line.toLowerCase(), isNot(contains('đầu gậy')), reason: line);
    }
  });

  test('chuỗi Hỏi huấn luyện viên đúng từng chữ (Task 10)', () {
    expect(Vi.coachChatTitle, 'Hỏi huấn luyện viên');
    expect(Vi.coachChatSubtitle, 'Trả lời dựa trên số liệu tập luyện của bạn');
    expect(Vi.coachChatSamples, const <String>[
      'Hôm nay tôi nên tập gì?',
      'Tại sao tôi thua trận vừa rồi?',
      'Tôi đang yếu kỹ năng nào?',
    ]);
    expect(Vi.coachChatOpen, 'Mở trò chuyện');
    expect(Vi.coachChatClear, 'Xoá cuộc trò chuyện');
    expect(Vi.coachChatThinking, 'Huấn luyện viên đang trả lời…');
    expect(Vi.coachChatInsufficient, 'Chưa đủ dữ liệu để trả lời câu này.');
    expect(Vi.coachChatRemaining(5), 'Còn 5 lượt hỏi hôm nay');
    expect(Vi.coachChatQuotaOut, 'Hết lượt hỏi hôm nay, mai hỏi tiếp.');
    expect(Vi.coachChatRetry, 'Thử lại');
    expect(
      Vi.coachChatDisclaimer,
      'Huấn luyện viên AI chỉ diễn giải số liệu của bạn và có thể sai.',
    );
    expect(
      Vi.coachChatClearBody,
      'Xoá mọi tin nhắn với huấn luyện viên trên máy này? Không lấy lại được.',
    );
    expect(Vi.coachChatClearYes, 'Xoá');
    expect(Vi.coachChatInputHint, 'Hỏi về việc tập của bạn');
    expect(Vi.coachChatSend, 'Gửi');
    expect(
      Vi.coachChatInsufficientHint,
      'Ghi thêm buổi tập, trận đấu hoặc tình huống Coach rồi hỏi lại.',
    );
    expect(Vi.coachChatError, 'Chưa gửi được câu hỏi.');
    expect(
      Vi.coachChatContextError,
      'Chưa đọc được số liệu tập luyện của bạn, nên chưa hỏi được.',
    );
    expect(Vi.coachChatFromPlayer, 'Bạn');
    expect(Vi.coachChatFromCoach, 'Huấn luyện viên');
  });

  test('chuỗi Hỏi huấn luyện viên không dính mẫu cấm chung của Coach', () {
    final lines = [
      ...Vi.coachChatSamples,
      Vi.coachChatTitle,
      Vi.coachChatSubtitle,
      Vi.coachChatOpen,
      Vi.coachChatClear,
      Vi.coachChatThinking,
      Vi.coachChatInsufficient,
      Vi.coachChatRemaining(5),
      Vi.coachChatQuotaOut,
      Vi.coachChatRetry,
      Vi.coachChatDisclaimer,
      Vi.coachChatClearBody,
      Vi.coachChatClearYes,
      Vi.coachChatInputHint,
      Vi.coachChatSend,
      Vi.coachChatInsufficientHint,
      Vi.coachChatError,
      Vi.coachChatContextError,
      Vi.coachChatFromPlayer,
      Vi.coachChatFromCoach,
    ];
    for (final line in lines) {
      expect(coachBannedRule(line), isNull, reason: line);
    }
  });
}
