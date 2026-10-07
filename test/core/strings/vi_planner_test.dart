import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

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
  });

  test('câu PRD giữ nguyên văn', () {
    expect(Vi.planRiskWarning,
        'Lực cao / dùng trô — quá tay hoặc quá áp phê dễ chết cái hoặc sai số lớn hơn bình thường.');
    expect(Vi.planMissAdvice(MissSide.thick),
        'Nếu trượt: nên đánh dư dày một chút — bi sẽ khó cho đối thủ hơn.');
    expect(Vi.planMissAdvice(MissSide.thin),
        'Nếu trượt: nên đánh dư mỏng một chút — bi sẽ khó cho đối thủ hơn.');
    expect(Vi.planNoPosition, 'Không có vị trí tốt cho bi sau.');
    expect(Vi.planSafety, 'Không có cú nào đưa bi vào lỗ an toàn — nên phòng thủ.');
    expect(Vi.planCueStoppedQuestion, 'Bi cái dừng đúng chỗ dự kiến?');
    expect(Vi.planOrderHint, 'Chạm theo đúng thứ tự số: bi 1 trước, bi 2 sau…');
  });

  test('chú giải lấy ngưỡng từ hằng số, không viết tay', () {
    final legend = Vi.planLegend.join('\n');
    expect(legend, contains('≤ ${zoneGood.round()}°'));
    expect(legend, contains('≤ ${zoneFair.round()}°'));
    expect(legend, contains('±${powerJitter.round()}%'));
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
        'Bàn kế hoạch. Bước 1 / 1: Không có cú nào đưa bi vào lỗ an toàn — nên phòng thủ.');
    expect(Vi.planSummary(null, index: 0, total: 9), 'Bàn kế hoạch. Đang tính bước 1/9…');
    expect(Vi.planSetupSummary(hasCue: false, balls: 0), 'Bàn bày bi. Chưa đặt bi cái.');
    expect(Vi.planSetupSummary(hasCue: true, balls: 3), 'Bàn bày bi. Đã đặt bi cái, 3 bi mục tiêu.');
  });
}
