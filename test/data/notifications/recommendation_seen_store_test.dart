import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/notifications/recommendation_seen_store.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'poolcoachai:recommendation-seen:v1:u1';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('lưu và đọc theo tài khoản, không lẫn', () async {
    final store = SharedPreferencesRecommendationSeenStore();
    final seen = SeenRecommendation(
      cat: SkillCategory.bank,
      drillId: 'd8',
      at: DateTime(2026, 9, 22, 10),
    );

    await store.save('u1', seen);

    expect(await store.load('u1'), seen);
    expect(await store.load('u2'), isNull);
  });

  test('giá trị hỏng hoặc nhóm lạ: coi như chưa thấy', () async {
    final store = SharedPreferencesRecommendationSeenStore();

    SharedPreferences.setMockInitialValues({
      key: '{"cat":"nope","drillId":"d1","at":"2026-09-22T10:00:00.000"}',
    });
    expect(await store.load('u1'), isNull);

    SharedPreferences.setMockInitialValues({key: '{'});
    expect(await store.load('u1'), isNull);
  });
}
