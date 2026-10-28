import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/match_analysis/shot_skill_map.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/match_fixtures.dart';

const p = RackWinner.player;
const o = RackWinner.opponent;
const B = MatchShotType.breakShot;
const N = MatchShotType.normal;
const S = MatchShotType.safety;
const made = MatchShotOutcome.made;
const missed = MatchShotOutcome.missed;
const foul = MatchShotOutcome.foul;
const scratch = MatchShotOutcome.scratch;
const bad = PositionOutcome.unsuccessful;
const ok = PositionOutcome.successful;

SkillAttempt a(SkillCategory c, bool failed) => (category: c, failed: failed);

void main() {
  test('cú phá: vào bi là không hỏng, còn lại là hỏng', () {
    final m = completedMatch('m', [p, p, p], [
      shotAt(1, 1, p, B, made),
      shotAt(2, 1, p, B, missed),
      shotAt(3, 1, p, B, scratch),
    ]);
    expect(shotSkillMap(m), [
      a(SkillCategory.breakShot, false),
      a(SkillCategory.breakShot, true),
      a(SkillCategory.breakShot, true),
    ]);
  });

  test('cú thường: vào bi và trượt quy về Tấn công', () {
    final m = completedMatch('m', [p], [
      shotAt(1, 1, p, B, made),
      shotAt(1, 2, p, N, missed),
      shotAt(1, 3, p, N, made),
    ]);
    expect(shotSkillMap(m), [
      a(SkillCategory.breakShot, false),
      a(SkillCategory.aiming, true),
      a(SkillCategory.aiming, false),
    ]);
  });

  test('cú thường phạm lỗi không quy về nhóm nào', () {
    final m = completedMatch('m', [p], [
      shotAt(1, 1, p, B, made),
      shotAt(1, 2, p, N, foul),
      shotAt(1, 3, p, N, made),
    ]);
    final map = shotSkillMap(m);
    expect(map.where((x) => x.category == SkillCategory.aiming).length, 1);
    expect(map, [
      a(SkillCategory.breakShot, false),
      a(SkillCategory.aiming, false),
    ]);
  });

  test('chết cái ở cú thường là một lần hỏng Điều bi, không tính Tấn công', () {
    final m = completedMatch('m', [o], [
      shotAt(1, 1, p, B, made),
      shotAt(1, 2, p, N, scratch),
      shotAt(1, 3, o, N, made),
    ]);
    expect(shotSkillMap(m), [
      a(SkillCategory.breakShot, false),
      a(SkillCategory.position, true),
    ]);
  });

  test('chết cái ở cú thường tính một lần cho Điều bi dù đã chấm điều bi hỏng', () {
    final m = completedMatch('m', [o], [
      shotAt(1, 1, p, B, made),
      shotAt(1, 2, p, N, scratch, position: bad),
      shotAt(1, 3, o, N, made),
    ]);
    final position =
        shotSkillMap(m).where((x) => x.category == SkillCategory.position);
    expect(position.toList(), [a(SkillCategory.position, true)]);
  });

  test('cú vào bi có chấm điều bi thì thêm một lần thử Điều bi', () {
    final m = completedMatch('m', [p], [
      shotAt(1, 1, p, B, made),
      shotAt(1, 2, p, N, made, position: ok),
      shotAt(1, 3, p, N, missed, position: bad),
      shotAt(1, 4, p, N, made),
    ]);
    expect(shotSkillMap(m), [
      a(SkillCategory.breakShot, false),
      a(SkillCategory.aiming, false),
      a(SkillCategory.position, false),
      a(SkillCategory.aiming, true),
      a(SkillCategory.position, true),
      a(SkillCategory.aiming, false),
    ]);
  });

  test('phòng thủ thất bại khi cú kế tiếp của đối thủ vào bi', () {
    final m = completedMatch('m', [o], [
      shotAt(1, 1, p, B, made),
      shotAt(1, 2, p, S, missed),
      shotAt(1, 3, o, N, made),
    ]);
    expect(shotSkillMap(m), contains(a(SkillCategory.safety, true)));
  });

  test('phòng thủ thành công khi cú kế tiếp của đối thủ trượt', () {
    final m = completedMatch('m', [p], [
      shotAt(1, 1, p, B, made),
      shotAt(1, 2, p, S, missed),
      shotAt(1, 3, o, N, missed),
      shotAt(1, 4, p, N, made),
    ]);
    expect(
      shotSkillMap(m).where((x) => x.category == SkillCategory.safety).toList(),
      [a(SkillCategory.safety, false)],
    );
  });

  test('phòng thủ là cú cuối của ván chưa đủ thì không chấm', () {
    final m = completedMatch('m', [o], [
      shotAt(1, 1, p, B, made),
      shotAt(1, 2, p, S, missed),
    ]);
    expect(shotSkillMap(m).any((x) => x.category == SkillCategory.safety),
        isFalse);
  });

  test('phòng thủ mà cú kế tiếp vẫn của người chơi thì không chấm', () {
    final m = completedMatch('m', [p], [
      shotAt(1, 1, p, B, made),
      shotAt(1, 2, p, S, missed),
      shotAt(1, 3, p, N, made),
    ]);
    expect(shotSkillMap(m).any((x) => x.category == SkillCategory.safety),
        isFalse);
  });

  test('ván chưa ghi đủ cú thì phòng thủ không chấm dù cú kế là của đối thủ', () {
    // Người chơi thắng nhưng cú cuối là cú trượt của đối thủ: ván không đủ.
    final m = completedMatch('m', [p], [
      shotAt(1, 1, p, B, made),
      shotAt(1, 2, p, S, missed),
      shotAt(1, 3, o, N, missed),
    ]);
    expect(shotSkillMap(m).any((x) => x.category == SkillCategory.safety),
        isFalse);
  });

  test('cú của đối thủ không vào nhóm nào', () {
    final m = completedMatch('m', [o], [
      shotAt(1, 1, o, B, made),
      shotAt(1, 2, o, N, missed, position: bad),
      shotAt(1, 3, o, S, missed),
      shotAt(1, 4, o, N, made),
    ]);
    expect(shotSkillMap(m), isEmpty);
  });

  test('cú thuộc ván chưa có người thắng bị bỏ qua', () {
    final m = completedMatch('m', [p], [
      shotAt(1, 1, p, B, made),
      shotAt(2, 1, p, B, missed),
      shotAt(2, 2, p, N, missed),
    ]);
    expect(shotSkillMap(m), [a(SkillCategory.breakShot, false)]);
  });
}
