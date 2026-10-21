import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/repository_providers.dart';
import 'package:poolcoachai/data/sync/coach_sync.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';

/// Service đồng bộ lần làm Coach đã chạy sẵn, như `roadmapSyncProvider`.
final coachSyncProvider = Provider<CoachSyncService>((ref) {
  final service = CoachSyncService(
    db: ref.watch(appDatabaseProvider),
    auth: ref.watch(authRepositoryProvider),
    api: ref.watch(directusClientProvider),
    now: ref.watch(nowProvider),
  )..start();
  ref.onDispose(service.dispose);
  return service;
});

/// Lần làm Coach của người đang đăng nhập, mới nhất trước. Chưa đăng nhập
/// thì rỗng.
final coachAttemptsProvider = StreamProvider<List<CoachAttempt>>((ref) {
  final repo = ref.watch(coachAttemptRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchAttempts();
});
