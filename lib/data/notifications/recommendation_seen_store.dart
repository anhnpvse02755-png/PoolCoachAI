import 'dart:convert';

import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nơi nhớ cặp (nhóm, bài) gợi ý mà người chơi thấy lần cuối, theo tài khoản,
/// chỉ trên máy này.
abstract class RecommendationSeenStore {
  Future<SeenRecommendation?> load(String userId);

  Future<void> save(String userId, SeenRecommendation seen);
}

/// Lưu bằng shared_preferences (localStorage trên web). Giá trị hỏng hoặc
/// nhóm lạ đọc ra như chưa thấy gì.
class SharedPreferencesRecommendationSeenStore
    implements RecommendationSeenStore {
  static String _key(String userId) =>
      'poolcoachai:recommendation-seen:v1:$userId';

  @override
  Future<SeenRecommendation?> load(String userId) async {
    final store = await SharedPreferences.getInstance();
    final raw = store.getString(_key(userId));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final catName = json['cat'];
      final drillId = json['drillId'];
      final at = json['at'];
      if (catName is! String || drillId is! String || at is! String) {
        return null;
      }
      SkillCategory? cat;
      for (final c in SkillCategory.values) {
        if (c.name == catName) cat = c;
      }
      final time = DateTime.tryParse(at);
      if (cat == null || time == null || drillId.isEmpty) return null;
      return SeenRecommendation(cat: cat, drillId: drillId, at: time);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(String userId, SeenRecommendation seen) async {
    final store = await SharedPreferences.getInstance();
    await store.setString(
      _key(userId),
      jsonEncode({
        'cat': seen.cat.name,
        'drillId': seen.drillId,
        'at': seen.at.toIso8601String(),
      }),
    );
  }
}
