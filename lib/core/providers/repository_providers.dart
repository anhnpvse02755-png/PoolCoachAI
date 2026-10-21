import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/data/repositories/drift_repositories.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/data/repositories/drill_log_repository.dart';
import 'package:poolcoachai/data/repositories/drift_match_repository.dart';
import 'package:poolcoachai/data/repositories/match_repository.dart';
import 'package:poolcoachai/data/repositories/practice_repository.dart';
import 'package:poolcoachai/data/repositories/seed_repositories.dart';

/// Repository providers — swap implementations by overriding these.
final drillRepositoryProvider = Provider<DrillRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftDrillRepository(db);
});

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftKnowledgeRepository(db);
});

/// Buổi tập của người đang đăng nhập. Đổi người thì provider dựng lại,
/// và mọi màn đọc buổi tập tự đổi theo.
final drillLogRepositoryProvider = Provider<DrillLogRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const SignedOutDrillLogRepository();
  return DriftDrillLogRepository(
    ref.watch(appDatabaseProvider),
    userId: userId,
  );
});

final timerSessionRepositoryProvider = Provider<TimerSessionRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const SignedOutTimerSessionRepository();
  return DriftTimerSessionRepository(
    ref.watch(appDatabaseProvider),
    userId: userId,
  );
});

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const SignedOutScheduleRepository();
  return DriftScheduleRepository(
    ref.watch(appDatabaseProvider),
    userId: userId,
  );
});

final cueEquipmentRepositoryProvider = Provider<CueEquipmentRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const SignedOutCueEquipmentRepository();
  return DriftCueEquipmentRepository(
    ref.watch(appDatabaseProvider),
    userId: userId,
    now: ref.watch(nowProvider),
  );
});

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const SignedOutMatchRepository();
  return DriftMatchRepository(ref.watch(appDatabaseProvider), userId: userId);
});
