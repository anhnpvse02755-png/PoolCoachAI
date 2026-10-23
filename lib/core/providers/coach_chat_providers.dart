import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/config.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/coach_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/player_intelligence_provider.dart';
import 'package:poolcoachai/core/providers/recommendation_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/data/remote/coach_chat_client.dart';
import 'package:poolcoachai/data/repositories/coach_chat_repository.dart';
import 'package:poolcoachai/domain/coach/coach_context.dart';

/// Backend Coach Chat (Giai đoạn B, Task 8): client HTTP thật tới dịch vụ
/// trung gian. Widget test luôn ghi đè provider này (`testContainer`), nên
/// không test nào chạm tới mạng.
final coachChatBackendProvider = Provider<CoachChatBackend>(
  (ref) => RemoteCoachChat(
    client: ref.watch(httpClientProvider),
    baseUrl: Uri.parse(coachChatUrl),
    auth: ref.watch(authRepositoryProvider),
  ),
);

/// Đã tải xong và không phải giá trị cũ của tài khoản trước (đang tải lại) —
/// như `_ready` trong `roadmap_providers.dart`. Chỉ `hasValue` là chưa đủ:
/// một `StreamProvider` đang xây lại (vd. đổi tài khoản) vẫn giữ giá trị cũ
/// kèm `isLoading == true`; dùng giá trị đó sẽ lẫn dữ liệu tài khoản trước
/// vào ngữ cảnh Coach Chat của tài khoản mới (controller review Task 9).
bool _ready(AsyncValue<Object?> value) => value.hasValue && !value.isLoading;

/// Ngữ cảnh gửi cho Coach Chat (R21): gộp sáu nguồn, mọi số đã tính sẵn
/// (spec Giai đoạn B mục 7 — LLM chỉ diễn giải, không tính lại).
final coachContextProvider = Provider<AsyncValue<CoachContext>>((ref) {
  final pi = ref.watch(playerIntelligenceProvider);
  final rankAsync = ref.watch(playerRankProvider);
  final roadmapAsync = ref.watch(roadmapProvider);
  final attemptsAsync = ref.watch(coachAttemptsProvider);
  final todayAsync = ref.watch(todayRecommendationProvider);
  final matchesAsync = ref.watch(matchesProvider);

  if (rankAsync.hasError) return AsyncError(rankAsync.error!, rankAsync.stackTrace!);
  if (roadmapAsync.hasError) return AsyncError(roadmapAsync.error!, roadmapAsync.stackTrace!);
  if (attemptsAsync.hasError) return AsyncError(attemptsAsync.error!, attemptsAsync.stackTrace!);
  if (todayAsync.hasError) return AsyncError(todayAsync.error!, todayAsync.stackTrace!);
  if (matchesAsync.hasError) return AsyncError(matchesAsync.error!, matchesAsync.stackTrace!);

  if (pi == null ||
      !_ready(rankAsync) ||
      !_ready(roadmapAsync) ||
      !_ready(attemptsAsync) ||
      !_ready(todayAsync) ||
      !_ready(matchesAsync)) {
    return const AsyncLoading();
  }

  return AsyncData(
    buildCoachContext(
      pi: pi,
      rank: rankAsync.requireValue?.rank,
      currentStep: roadmapAsync.requireValue?.currentStep,
      attempts: attemptsAsync.requireValue,
      today: todayAsync.requireValue,
      matches: matchesAsync.requireValue,
    ),
  );
});

/// Lịch sử Coach Chat của người đang đăng nhập; null khi chưa đăng nhập.
final coachChatRepositoryProvider = Provider<CoachChatRepository?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return CoachChatRepository(ref.watch(appDatabaseProvider), userId: userId);
});

/// Lượt chat của người đang đăng nhập, cũ nhất trước; rỗng khi chưa đăng
/// nhập.
final coachChatTurnsProvider = StreamProvider<List<CoachChatEntry>>((ref) {
  final repo = ref.watch(coachChatRepositoryProvider);
  return repo?.watchTurns() ?? Stream.value(const []);
});
