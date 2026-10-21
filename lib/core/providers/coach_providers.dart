import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/player_intelligence_provider.dart';
import 'package:poolcoachai/core/providers/recommendation_provider.dart';
import 'package:poolcoachai/core/providers/repository_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/data/sync/coach_sync.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_recommendation.dart';
import 'package:poolcoachai/domain/coach/generator.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';

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

/// Lõi tính của Coach: vật lý thật và lát [sliceBudget]. Widget test thay để
/// không chạy vật lý thật hay chạy một mạch trong một khung hình.
class CoachEngine {
  const CoachEngine({this.aim = aimShot, this.safety = const SafetyPhysics(), this.budget = sliceBudget});

  final AimShotFn aim;
  final SafetyPhysics safety;

  /// Lát tính mỗi khung hình.
  final Duration budget;
}

final coachEngineProvider = Provider<CoachEngine>((ref) => const CoachEngine());

/// Tình huống đã sinh sẵn (spec mục 8.7), theo khoá: bấm "Tình huống mới"
/// thì màn mới lấy đúng việc đã tính, không tính lại.
final coachPregeneratedProvider = Provider<Map<String, CoachGenerateJob>>((ref) => {});

/// Thẻ "Nên luyện gì" (spec mục 10); null khi dữ liệu chưa về.
final coachRecommendationProvider = Provider<CoachRecommendation?>((ref) {
  final pi = ref.watch(playerIntelligenceProvider);
  final today = ref.watch(todayRecommendationProvider);
  final attempts = ref.watch(coachAttemptsProvider);
  final knowledge = ref.watch(knowledgeProvider);
  if (pi == null || !attempts.hasValue || !knowledge.hasValue) return null;
  return computeCoachRecommendation(
    today: today.value,
    pi: pi,
    attempts: attempts.requireValue,
    articles: knowledge.requireValue,
  );
});
