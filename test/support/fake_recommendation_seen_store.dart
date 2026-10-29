import 'dart:async';

import 'package:poolcoachai/data/notifications/recommendation_seen_store.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';

/// Kho "đã thấy" giả cho test: ghi vào [saved]; đặt [hold] để giữ [load]
/// treo tới khi cổng hoàn tất.
class FakeRecommendationSeenStore implements RecommendationSeenStore {
  final saved = <String, SeenRecommendation>{};
  Completer<void>? hold;

  @override
  Future<SeenRecommendation?> load(String userId) async {
    await hold?.future;
    return saved[userId];
  }

  @override
  Future<void> save(String userId, SeenRecommendation seen) async {
    saved[userId] = seen;
  }
}
