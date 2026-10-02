import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

void main() {
  const none = SideSpin.none();
  const right1 = SideSpin(SpinSide.right, 1);
  const right2 = SideSpin(SpinSide.right, 2);
  const left1 = SideSpin(SpinSide.left, 1);

  test('thuật ngữ đã chốt với chủ sản phẩm', () {
    expect(Vi.simStroke(Stroke.stun), 'Đánh đứng bi');
    expect(Vi.simStroke(Stroke.draw), 'Đánh trô bi');
    expect(Vi.simStroke(Stroke.follow), 'Đánh cu lê');
    expect(Vi.simStrokeLabel, 'Kiểu đánh');
    expect(Vi.simMiscue, 'Lệch 2 đầu cơ dễ trượt cơ.');
  });

  test('số đầu cơ không có số 0 thừa', () {
    expect(Vi.simTips(0.5), '0.5');
    expect(Vi.simTips(1), '1');
    expect(Vi.simTips(2), '2');
    expect(Vi.simSpinChip(none), 'Không');
    expect(Vi.simSpinChip(right1), 'Phải 1');
    expect(Vi.simSpinLine(const SideSpin(SpinSide.left, 0.5)),
        'Áp phê: trái lệch 0.5 đầu cơ');
  });

  test('lời khuyên dùng đúng chiều ít/nhiều áp phê', () {
    expect(
      Vi.simAdvice(const AddSpinToAvoid(from: none, to: right1, pocket: Pocket.topRight)),
      'Ít áp phê thì bi cái chết cái ở lỗ góc trên phải — nên áp phê phải '
      'lệch 1 đầu cơ để đổi góc bật tránh lỗ.',
    );
    expect(
      Vi.simAdvice(const AddSpinToAvoid(from: right2, to: right1, pocket: Pocket.topMiddle)),
      'Áp phê nhiều quá, bi cái chết cái ở lỗ giữa trên — giảm còn áp phê '
      'phải lệch 1 đầu cơ.',
    );
    expect(
      Vi.simAdvice(const AddSpinToAvoid(from: left1, to: right1, pocket: Pocket.topMiddle)),
      'Áp phê trái làm bi cái chết cái ở lỗ giữa trên — nên đổi sang áp phê '
      'phải lệch 1 đầu cơ.',
    );
    expect(
      Vi.simAdvice(const AddSpinToAvoid(from: right1, to: none, pocket: Pocket.topMiddle)),
      'Áp phê đang chọn làm bi cái chết cái ở lỗ giữa trên — đánh không áp '
      'phê thì tránh được.',
    );
  });

  // Mức đầu cơ gợi ý mà dễ trượt cơ thì câu khuyên phải nói luôn, không đợi
  // người chơi chọn mức đó mới thấy cảnh báo.
  test('lời khuyên gợi ý mức dễ trượt cơ thì kèm cảnh báo Trượt cơ', () {
    expect(const SideSpin(SpinSide.right, 2).risksMiscue, isTrue);
    expect(
      Vi.simAdvice(const AddSpinToAvoid(from: none, to: right2, pocket: Pocket.topRight)),
      'Ít áp phê thì bi cái chết cái ở lỗ góc trên phải — nên áp phê phải '
      'lệch 2 đầu cơ (dễ Trượt cơ) để đổi góc bật tránh lỗ.',
    );
    expect(
      Vi.simAdvice(const AddSpinToAvoid(from: left1, to: right2, pocket: Pocket.topMiddle)),
      'Áp phê trái làm bi cái chết cái ở lỗ giữa trên — nên đổi sang áp phê '
      'phải lệch 2 đầu cơ (dễ Trượt cơ).',
    );
    expect(
      Vi.simAdvice(const OverhitRisk(
        margin: 12,
        fromPower: 82,
        pocket: Pocket.topRight,
        saferSpin: right2,
      )),
      'Nếu đánh quá lực khoảng +12% (từ ~82%), bi cái có thể rơi lỗ góc trên '
      'phải (chết cái). Áp phê phải lệch 2 đầu cơ (dễ Trượt cơ) thì vẫn an '
      'toàn tới 100%.',
    );
  });

  test('cảnh báo dư lực ghép số tính ra', () {
    expect(
      Vi.simAdvice(const OverhitRisk(
        margin: 12,
        fromPower: 82,
        pocket: Pocket.topRight,
        saferSpin: left1,
      )),
      'Nếu đánh quá lực khoảng +12% (từ ~82%), bi cái có thể rơi lỗ góc trên '
      'phải (chết cái). Áp phê trái lệch 1 đầu cơ thì vẫn an toàn tới 100%.',
    );
    expect(
      Vi.simAdvice(const SpinCeiling(
          side: SpinSide.right, maxSafeTips: 0.5, pocket: Pocket.bottomMiddle)),
      'Đừng áp phê phải quá 0.5 đầu cơ — bi cái sẽ rơi lỗ giữa dưới.',
    );
  });

  test('nhãn tóm tắt của bàn', () {
    const g = ShotGeometry(
      cue: Vec2(80, 90),
      object: Vec2(170, 50),
      pocket: Pocket.topRight,
      ghost: Vec2(165, 53),
      objectDir: Vec2(1, 0),
      tangentDir: Vec2(0, 1),
      aimDir: Vec2(1, 0),
      angle: 7.4,
    );
    const path = CueBallPath(
      segments: [Straight(Vec2(165, 53), Vec2(170, 60))],
      end: Vec2(170, 60),
    );
    expect(Vi.simSummary(const Makeable(g), path),
        'Bàn mô phỏng. Lỗ góc trên phải, góc cắt 7°, Dễ.');
    expect(Vi.simSummary(null, null),
        'Bàn mô phỏng. Không lỗ nào đánh được từ vị trí này.');
    expect(Vi.simSummary(const Unmakeable(UnmakeableReason.tooThin), null),
        'Bàn mô phỏng. Góc cắt quá lớn (>85°).');
    expect(Vi.simBand(bandFor(7.4)), 'Dễ');
  });

  test('simSummary append dội băng khi path có railHit', () {
    const g = ShotGeometry(
      cue: Vec2(80, 90),
      object: Vec2(170, 50),
      pocket: Pocket.topRight,
      ghost: Vec2(165, 53),
      objectDir: Vec2(1, 0),
      tangentDir: Vec2(0, 1),
      aimDir: Vec2(1, 0),
      angle: 7.4,
    );
    const bankPath = CueBallPath(
      segments: [
        Straight(Vec2(165, 53), Vec2(251.1425, 80)),
        Straight(Vec2(251.1425, 80), Vec2(200, 100))
      ],
      end: Vec2(200, 100),
      railHit: Vec2(251.1425, 80),
    );
    expect(Vi.simSummary(const Makeable(g), bankPath),
        'Bàn mô phỏng. Lỗ góc trên phải, góc cắt 7°, Dễ. Dội băng.');
  });

  test('simSummary append chết cái khi path có scratch', () {
    const g = ShotGeometry(
      cue: Vec2(80, 90),
      object: Vec2(170, 50),
      pocket: Pocket.topRight,
      ghost: Vec2(165, 53),
      objectDir: Vec2(1, 0),
      tangentDir: Vec2(0, 1),
      aimDir: Vec2(1, 0),
      angle: 7.4,
    );
    const scratchPath = CueBallPath(
      segments: [Straight(Vec2(165, 53), Vec2(250, 4))],
      end: Vec2(250, 4),
      scratch: Pocket.topRight,
    );
    expect(Vi.simSummary(const Makeable(g), scratchPath),
        'Bàn mô phỏng. Lỗ góc trên phải, góc cắt 7°, Dễ. Chết cái.');
  });

  test('Vi.simAdvice với NoSpinAvoids', () {
    expect(
      Vi.simAdvice(const NoSpinAvoids(pocket: Pocket.topRight)),
      'Bi cái chết cái ở lỗ góc trên phải, áp phê không cứu được — đổi lực hoặc kiểu đánh.',
    );
  });
}
