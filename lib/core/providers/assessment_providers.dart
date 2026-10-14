import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/data/repositories/assessment_repository.dart';
import 'package:poolcoachai/data/sync/assessment_sync.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/onboarding_check.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:uuid/uuid.dart';

/// Hạng và bài kiểm tra của người đang đăng nhập; null khi chưa đăng nhập.
/// Đổi người thì provider dựng lại, mọi màn đọc hạng tự đổi theo.
final assessmentRepositoryProvider = Provider<AssessmentRepository?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return AssessmentRepository(
    ref.watch(appDatabaseProvider),
    userId: userId,
    now: ref.watch(nowProvider),
    newId: const Uuid().v4,
  );
});

final playerRankProvider = StreamProvider<PlayerRank?>((ref) {
  final repo = ref.watch(assessmentRepositoryProvider);
  return repo == null ? Stream.value(null) : repo.watchRank();
});

/// Mọi lần kiểm tra, mới nhất trước — lịch sử và giãn cách 14 ngày.
final buTestsProvider = StreamProvider<List<BuTest>>((ref) {
  final repo = ref.watch(assessmentRepositoryProvider);
  return repo == null ? Stream.value(const []) : repo.watchTests();
});

final activeTestProvider = StreamProvider<TestSnapshot?>((ref) {
  final repo = ref.watch(assessmentRepositoryProvider);
  return repo == null ? Stream.value(null) : repo.watchActiveTest();
});

final testSnapshotProvider = StreamProvider.family<TestSnapshot?, String>((ref, testId) {
  final repo = ref.watch(assessmentRepositoryProvider);
  return repo == null ? Stream.value(null) : repo.watchTest(testId);
});

typedef RankFetchState = ({String userId, RankFetch fetch});

/// Lần lấy hạng gần nhất từ máy chủ, do [AssessmentSyncService] báo.
///
/// Đã hỏng một lần cho người này thì giữ "hỏng" tới khi đổi người: spec
/// mục 8 nói lấy không được thì không ép onboarding — một lượt thành công
/// về sau không được kéo người chơi vào onboarding giữa lúc đang dùng app.
class RankFetchNotifier extends Notifier<RankFetchState?> {
  @override
  RankFetchState? build() => null;

  void report(String userId, RankFetch fetch) {
    final s = state;
    if (s != null && s.userId == userId && s.fetch == RankFetch.failed) return;
    state = (userId: userId, fetch: fetch);
  }
}

RankFetch rankFetchFor(RankFetchState? state, String userId) =>
    state != null && state.userId == userId ? state.fetch : RankFetch.pending;

final rankFetchProvider =
    NotifierProvider<RankFetchNotifier, RankFetchState?>(RankFetchNotifier.new);

/// Service đã chạy sẵn, như [syncServiceProvider].
final assessmentSyncProvider = Provider<AssessmentSyncService>((ref) {
  final service = AssessmentSyncService(
    db: ref.watch(appDatabaseProvider),
    auth: ref.watch(authRepositoryProvider),
    api: ref.watch(directusClientProvider),
    now: ref.watch(nowProvider),
    onRankFetch: ref.read(rankFetchProvider.notifier).report,
  )..start();
  ref.onDispose(service.dispose);
  return service;
});
