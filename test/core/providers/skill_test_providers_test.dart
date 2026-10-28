import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/skill_test_providers.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';
import 'package:poolcoachai/domain/skill_test/skill_test_gate.dart';

import '../../support/skill_test_fixtures.dart';
import '../../support/test_data.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await pumpEventQueue();
  }
}

ProviderContainer make({
  List<DrillLog>? logs,
  List<SkillTest>? tests,
  AsyncValue<List<SkillTest>>? asyncTests,
  String drillId = 'a1',
}) {
  final c = testContainer(
    drills: stDrills,
    logs: logs,
    skillTests: tests,
    skillTestsAsync: asyncTests,
  );
  addTearDown(c.dispose);
  c.listen(skillTestGateProvider(drillId), (_, _) {});
  c.listen(certificationsProvider, (_, _) {});
  c.listen(certificationSummaryProvider, (_, _) {});
  c.listen(testableDrillIdsProvider, (_, _) {});
  return c;
}

void main() {
  test(
    'a1 đủ 3 buổi đạt: cổng mở, có trong danh sách sẵn sàng kiểm tra',
    () async {
      final c = make(logs: threePasses('a1'));
      await settle();
      final state = c.read(skillTestGateProvider('a1')).value!;
      expect(state.gate, isA<SkillTestOpen>());
      expect(state.formSlipped, isFalse);
      expect(state.drill.id, 'a1');
      expect(state.logs, hasLength(3));
      expect(c.read(testableDrillIdsProvider).value, ['a1']);
    },
  );

  test('đã chứng nhận: cổng báo đã chứng nhận, danh sách sẵn sàng rỗng, có trong chứng nhận', () async {
    final c = make(
      logs: threePasses('a1'),
      tests: [passedTest('a1', 1, stToday)],
    );
    await settle();
    expect(
      c.read(skillTestGateProvider('a1')).value!.gate,
      isA<AlreadyCertified>(),
    );
    expect(c.read(testableDrillIdsProvider).value, isEmpty);
    expect(c.read(certificationsProvider).value!.keys, ['a1']);
    final summary = c.read(certificationSummaryProvider).value!;
    expect(summary.groups.expand((g) => g.entries).map((e) => e.drill.id), [
      'a1',
    ]);
  });

  test('cổng cấp thấp: giá trị mang đủ bài để gọi tên bài còn thiếu', () async {
    final c = make(logs: threePasses('a3'), drillId: 'a3');
    await settle();
    final state = c.read(skillTestGateProvider('a3')).value!;
    expect(state.gate, isA<NeedLowerLevel>());
    expect(state.missingLowerDrills.map((d) => d.id), ['a1']);
    expect(state.drills, stDrills);
  });

  test('phong độ gần đây chưa đạt: chỉ tính khi bài đã chứng nhận', () async {
    final slipped = [
      for (var i = 0; i < 5; i++)
        stLog('a1', 2, stToday.subtract(Duration(days: i + 1))),
    ];
    final notCertified = make(logs: slipped);
    await settle();
    // Chưa chứng nhận: 5 buổi trượt nhưng không có "phong độ chưa đạt".
    expect(
      notCertified.read(skillTestGateProvider('a1')).value!.formSlipped,
      isFalse,
    );

    final certified = make(
      logs: slipped,
      tests: [passedTest('a1', 1, stToday.subtract(const Duration(days: 20)))],
    );
    await settle();
    final state = certified.read(skillTestGateProvider('a1')).value!;
    expect(state.gate, isA<AlreadyCertified>());
    expect(state.formSlipped, isTrue);
  });

  test('bài không có trong thư viện: cổng là null, không ném', () async {
    final c = make(drillId: 'zz');
    await settle();
    final v = c.read(skillTestGateProvider('zz'));
    expect([v.hasValue, v.value], [true, null]);
  });

  test(
    'nguồn lần kiểm tra lỗi: mọi provider thành lỗi, không quay mãi',
    () async {
      final c = make(
        logs: threePasses('a1'),
        asyncTests: AsyncError<List<SkillTest>>(
          StateError('hỏng'),
          StackTrace.empty,
        ),
      );
      await settle();
      expect(
        [
          c.read(skillTestGateProvider('a1')).hasError,
          c.read(certificationsProvider).hasError,
          c.read(certificationSummaryProvider).hasError,
          c.read(testableDrillIdsProvider).hasError,
        ],
        [true, true, true, true],
      );
      expect(c.read(certificationsProvider).error, isA<StateError>());
    },
  );

  test('đang tải lại còn chứng nhận của người trước: là đang tải, không dùng giá trị cũ', () async {
    // ignore: invalid_use_of_internal_member
    final stale = const AsyncLoading<List<SkillTest>>().copyWithPrevious(
      AsyncData<List<SkillTest>>([passedTest('a1', 1, stToday)]),
    );
    final c = make(logs: threePasses('a1'), asyncTests: stale);
    await settle();
    expect(
      [
        c.read(skillTestGateProvider('a1')).isLoading,
        c.read(certificationsProvider).isLoading,
        c.read(certificationSummaryProvider).isLoading,
        c.read(testableDrillIdsProvider).isLoading,
      ],
      [true, true, true, true],
    );
  });
}
