import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';

import '../../support/table_layouts.dart';

void main() {
  test('thuật ngữ đã chốt với chủ sản phẩm (05/10)', () {
    expect(Vi.planTitle, 'Kế hoạch dọn bàn');
    expect(Vi.planGroup(BallGroup.solids), 'Trơn');
    expect(Vi.planGroup(BallGroup.stripes), 'Sọc');
    expect(GameType.values.map(Vi.planGame), ['9 bi', '10 bi', '8 bi']);
    expect(BallRole.values.map(Vi.planPlacing), ['Bi của tôi', 'Bi đối thủ', 'Bi 8']);
  });

  test('câu có số là khuôn, số do lõi điền', () {
    expect(Vi.planComputing(3, 9), 'Đang tính bước 3/9…');
    expect(Vi.planStepHeader(3, 9), 'Bước 3 / 9');
    expect(Vi.planBallLine(7), 'Bi 7');
    expect(Vi.planTolerance(6, 7), '6/7 mức lực vẫn trong vùng điều tốt');
  });

  test('dội băng là thông tin, không còn vế 15%', () {
    expect(Vi.planRailInfo(2), 'Bi cái chạm băng 2 lần rồi tới vùng điều.');
    expect(Vi.planRailInfo(2), isNot(contains('15%')));
    // Bước cuối không có bi kế tiếp, nên không có vùng điều để tới.
    expect(Vi.planRailInfoLast(2), 'Bi cái chạm băng 2 lần.');
  });

  test('câu PRD giữ nguyên văn', () {
    expect(Vi.planRiskWarning,
        'Lực cao / dùng trô — quá tay hoặc quá áp phê dễ chết cái hoặc sai số lớn hơn bình thường.');
    expect(Vi.planMissAdvice(MissSide.thick),
        'Nếu trượt: nên đánh dư dày một chút — bi sẽ khó cho đối thủ hơn.');
    expect(Vi.planMissAdvice(MissSide.thin),
        'Nếu trượt: nên đánh dư mỏng một chút — bi sẽ khó cho đối thủ hơn.');
    expect(Vi.planNoPosition, 'Không có vị trí tốt cho bi sau.');
    // 9 / 10 bi: bi bắt buộc có số. 8 bi: không bi cụ thể nào bị ép.
    expect(Vi.planSafety(3),
        'Bi 3 không có đường đánh rõ ràng vào lỗ nào (bị chắn hoặc góc quá khó) — '
        'nên chơi an toàn (safety) thay vì cố đánh.');
    expect(Vi.planSafety(null),
        'Không bi nào có đường đánh rõ ràng vào lỗ nào (bị chắn hoặc góc quá khó) — '
        'nên chơi an toàn (safety) thay vì cố đánh.');
    expect(Vi.planCueStoppedQuestion, 'Bi cái dừng đúng chỗ dự kiến?');
    expect(Vi.planOrderHint, 'Chạm theo đúng thứ tự số: bi 1 trước, bi 2 sau…');
  });

  test('chú giải lấy ngưỡng từ hằng số, không viết tay', () {
    final legend = Vi.planLegend.join('\n');
    expect(legend, contains('≤ ${zoneGood.round()}°'));
    expect(legend, contains('≤ ${zoneFair.round()}°'));
    expect(legend, contains('±${powerJitter.round()}%'));
  });

  test('điểm hỏi của cú thủ: lời chủ sản phẩm nguyên văn (08/10/2026)', () {
    expect(Vi.planSearchingSafety, 'Đang tìm cú thủ…');
    expect(Vi.planSafetyCheckpoint,
        'Tính toán cơ bản thì đánh như thế này là thủ tốt, có thể có phương án tối ưu hơn '
        'nhưng sẽ mất thời gian tính toán. Bạn muốn tính tiếp hay không?');
    expect((Vi.planSafetyContinue, Vi.planSafetyKeep), ('Tính tiếp', 'Dùng cú này'));
    expect(Vi.planSafetyProvisional, 'Cú thủ tạm tính — đang tìm cú tốt hơn…');
  });

  test('nhãn semantics tóm tắt bước đang xem', () {
    final g = geometryFor(tableCenter, Pocket.topRight, 20);
    final step = PlanStep(
        kind: PlanStepKind.normal,
        cbFrom: g.cue,
        ballNum: 3,
        geometry: g,
        stroke: Stroke.draw,
        power: 60);
    expect(Vi.planSummary(step, index: 1, total: 5),
        'Bàn kế hoạch. Bước 2 / 5: bi 3, lỗ góc trên phải, Đánh trô bi, lực 60%.');
    expect(Vi.planSummary(const PlanStep.safety(cbFrom: Vec2(1, 1), ballNum: 2), index: 0, total: 1),
        'Bàn kế hoạch. Bước 1 / 1: Bi 2 không có đường đánh rõ ràng vào lỗ nào '
        '(bị chắn hoặc góc quá khó) — nên chơi an toàn (safety) thay vì cố đánh.');
    expect(Vi.planSummary(const PlanStep.safety(cbFrom: Vec2(1, 1)), index: 0, total: 1),
        'Bàn kế hoạch. Bước 1 / 1: ${Vi.planSafety(null)}');
    expect(Vi.planSummary(null, index: 0, total: 9), 'Bàn kế hoạch. Đang tính bước 1/9…');
    expect(Vi.planSetupSummary(hasCue: false, balls: 0), 'Bàn bày bi. Chưa đặt bi cái.');
    expect(Vi.planSetupSummary(hasCue: true, balls: 3), 'Bàn bày bi. Đã đặt bi cái, 3 bi mục tiêu.');
  });

  group('cú phòng thủ (spec cú phòng thủ mục 5.2, thuật ngữ)', () {
    test('câu đầu: bị đui hay hết đường ăn', () {
      expect(Vi.safetySnookered(3), 'Bi cái bị đui bi 3 — đánh A băng để thủ.');
      expect(Vi.safetyNoPot, 'Không còn đường ăn bi — nên thủ bi.');
      expect(Vi.planSearchingSafety, 'Đang tìm cú thủ…');
    });

    test('A băng: số băng, chấm (dấu phẩy thập phân), tên băng theo hướng nhìn trên màn', () {
      expect(Vi.safetyKick(2, const RailAim(rail: Rail.top, diamond: 2.5, at: Vec2(80, 3))),
          'A băng 2 băng: ngắm chấm 2,5 băng dài trên.');
      expect(Vi.safetyKick(1, const RailAim(rail: Rail.right, diamond: 3, at: Vec2(251, 95))),
          'A băng 1 băng: ngắm chấm 3 băng ngắn phải.');
      expect(Rail.values.map(Vi.safetyRail),
          ['băng ngắn trái', 'băng ngắn phải', 'băng dài trên', 'băng dài dưới']);
    });

    test('độ dày: trọn bi, hoặc phân số kèm bên lệch', () {
      expect(Vi.safetyThickness(1, ThicknessSide.full), 'Ăn trọn bi.');
      expect(Vi.safetyThickness(0.5, ThicknessSide.left), 'Ăn ½ bi, lệch bên trái.');
      expect(Vi.safetyThickness(0.75, ThicknessSide.right), 'Ăn ¾ bi, lệch bên phải.');
      expect(Vi.safetyThickness(0.25, ThicknessSide.left), 'Ăn ¼ bi, lệch bên trái.');
      expect(Vi.safetyThickness(0.125, ThicknessSide.right), 'Ăn ⅛ bi, lệch bên phải.');
    });

    test('kết quả cho đối thủ: đui, cú dễ nhất có số độ, hoặc hết đường ăn', () {
      const ball = PlacedBall(number: 4, pos: Vec2(127, 100));
      expect(Vi.safetyOpponent(const OpponentView(snookered: true, ball: ball)), 'Đối thủ bị đui.');
      expect(Vi.safetyOpponent(const OpponentView(snookered: false, ball: ball)),
          'Đối thủ không còn đường ăn.');
      final g = bestPocket(cue: const Vec2(127, 63.5), object: ball.pos)!;
      expect(Vi.safetyOpponent(OpponentView(snookered: false, ball: ball, easiest: g)),
          'Cú dễ nhất của đối thủ: bi 4 vào lỗ ${Vi.simPocket(g.pocket)}, góc cắt ${g.angle.round()}°.');
      expect(Vi.safetyTolerance(5, 7), '5/7 mức lực vẫn để đối thủ khó.');
    });
  });
}
