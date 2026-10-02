import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

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

  group('nhãn tóm tắt của bàn', () {
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

    AimedShot aimed({
      List<RailHit> rails = const [],
      Pocket? cuePocket,
      double aimOffsetDeg = 0,
    }) =>
        AimedShot(
          trace: ShotTrace(
            cueBefore: const [Vec2(80, 90), Vec2(165, 53)],
            cueAfter: const [Vec2(165, 53), Vec2(200, 100)],
            objectPath: const [Vec2(170, 50), Vec2(254, 0)],
            contactCue: const Vec2(165, 53),
            rails: rails,
            cuePocket: cuePocket,
            objectPocket: Pocket.topRight,
            cueEnd: const Vec2(200, 100),
          ),
          uncompensated: null,
          aimOffsetDeg: aimOffsetDeg,
          verticalOffset: 0,
          converged: true,
        );

    test('đủ góc cắt, độ dốc cơ và độ bù ném', () {
      expect(
          Vi.simSummary(const Makeable(g), aimed(),
              elevation: CueElevation.normal),
          'Bàn mô phỏng. Lỗ góc trên phải, góc cắt 7°, Dễ. Độ dốc cơ: '
          'Thường. Không cần bù ném.');
      expect(
          Vi.simSummary(const Makeable(g), aimed(aimOffsetDeg: -1.2),
              elevation: CueElevation.steep),
          'Bàn mô phỏng. Lỗ góc trên phải, góc cắt 7°, Dễ. Độ dốc cơ: '
          'Dốc. Ngắm mỏng hơn 1°.');
      expect(Vi.simBand(bandFor(7.4)), 'Dễ');
    });

    test('không đánh được thì chỉ nói lý do', () {
      expect(Vi.simSummary(null, null, elevation: CueElevation.normal),
          'Bàn mô phỏng. Không lỗ nào đánh được từ vị trí này.');
      expect(
          Vi.simSummary(const Unmakeable(UnmakeableReason.tooThin), null,
              elevation: CueElevation.normal),
          'Bàn mô phỏng. Góc cắt quá lớn (>85°).');
    });

    test('thêm số lần bi cái chạm băng sau va chạm, chết cái, đường đỏ', () {
      const hit = RailHit(
          ball: ShotBall.cue,
          pos: Vec2(251.1425, 80),
          rail: Rail.right,
          afterContact: true);
      expect(
          Vi.simSummary(
              const Makeable(g),
              aimed(rails: const [hit, hit], cuePocket: Pocket.bottomLeft),
              elevation: CueElevation.normal,
              showingUncompensated: true),
          'Bàn mô phỏng. Lỗ góc trên phải, góc cắt 7°, Dễ. Độ dốc cơ: '
          'Thường. Không cần bù ném. Bi cái chạm băng 2 lần. Chết cái. '
          'Đang xem đường không bù ném.');
    });
  });

  test('Vi.simAdvice với NoSpinAvoids', () {
    expect(
      Vi.simAdvice(const NoSpinAvoids(pocket: Pocket.topRight)),
      'Bi cái chết cái ở lỗ góc trên phải, áp phê không cứu được — đổi lực hoặc kiểu đánh.',
    );
  });

  group('lõi vật lý', () {
    test('thuật ngữ mới đã chốt với chủ sản phẩm', () {
      expect(Vi.simElevationLabel, 'Độ dốc cơ');
      expect(Vi.simElevation(CueElevation.normal), 'Thường');
      expect(Vi.simElevation(CueElevation.steep), 'Dốc');
      expect(Vi.simElevationLine(CueElevation.steep), 'Độ dốc cơ: Dốc');
      expect(Vi.simCompensateToggle, 'Xem nếu không bù ném');
      expect(Vi.simComputing, 'Đang tính…');
      expect(Vi.simObjectMissed, 'Bi mục tiêu không vào lỗ.');
    });

    test('năm mức lực chỉ ghi phần trăm', () {
      expect([for (final p in powerPresets) Vi.simPowerPreset(p)],
          ['30%', '45%', '60%', '75%', '90%']);
    });

    test('ngắm dày/mỏng theo dấu, làm tròn 0.5°', () {
      expect(Vi.simAimOffset(1.24), 'Ngắm dày hơn 1°');
      expect(Vi.simAimOffset(1.26), 'Ngắm dày hơn 1.5°');
      expect(Vi.simAimOffset(-0.6), 'Ngắm mỏng hơn 0.5°');
      expect(Vi.simAimOffset(-2), 'Ngắm mỏng hơn 2°');
    });

    test('đặt cơ dưới tâm tính bằng đầu cơ, làm tròn 0.25', () {
      expect(Vi.simStunOffset(-0.66),
          'Đánh đứng bi: đặt cơ dưới tâm khoảng 0.5 đầu cơ');
      expect(Vi.simStunOffset(-1.714),
          'Đánh đứng bi: đặt cơ dưới tâm khoảng 1.25 đầu cơ');
      expect(Vi.simStunOffset(-1.25),
          'Đánh đứng bi: đặt cơ dưới tâm khoảng 1 đầu cơ');
    });

    test('lệch do áp phê và số lần chạm băng', () {
      expect(Vi.simSquirt(1.55), 'Bi cái bị lệch do áp phê khoảng 1.5°');
      expect(Vi.simSquirt(0.83), 'Bi cái bị lệch do áp phê khoảng 1°');
      expect(Vi.simRailCount(3), 'Bi cái chạm băng 3 lần.');
    });
  });
}
