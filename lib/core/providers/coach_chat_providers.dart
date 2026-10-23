import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/config.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/coach_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/player_intelligence_provider.dart';
import 'package:poolcoachai/core/providers/recommendation_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/remote/coach_chat_client.dart';
import 'package:poolcoachai/data/repositories/coach_chat_repository.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
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

/// Trạng thái màn Hỏi huấn luyện viên. `sending` khi câu hỏi đang gửi hoặc
/// vừa gửi mà chờ phản hồi; `failed` khi gửi hỏng và còn câu để "Thử lại".
enum CoachChatStatus { idle, sending, failed }

/// `pending`: câu đang chờ hoặc vừa gửi hỏng (chưa lưu). `remaining`: lượt
/// còn lại hôm nay; `null` là chưa biết.
typedef CoachChatState = ({CoachChatStatus status, String? pending, int? remaining});

/// Controller của màn Hỏi huấn luyện viên (Task 10).
///
/// `NotifierProvider` thường (không `.autoDispose`) — để ý R20 (giữ sống):
/// rời màn khi câu hỏi đang chờ thì câu trả lời vẫn tới và vẫn được lưu
/// (`addExchange` chạy xong), vì state của controller không bị dọn theo
/// widget của màn hình.
final coachChatControllerProvider = NotifierProvider<CoachChatController, CoachChatState>(CoachChatController.new);

class CoachChatController extends Notifier<CoachChatState> {
  bool _disposed = true;

  /// Tăng mỗi khi một câu hỏi (thành công, hết lượt, hay lỗi) xong việc —
  /// để `loadQuota()` bỏ kết quả của mình nếu đã có phản hồi mới hơn trả
  /// lời trong lúc nó đang chờ mạng (ruling controller).
  int _epoch = 0;

  @override
  CoachChatState build() {
    // Đổi tài khoản thì watch này đổi giá trị, build() chạy lại, trạng thái
    // về mặc định — không mang lịch sử gửi/đang chờ của tài khoản trước.
    ref.watch(currentUserIdProvider);
    _disposed = false;
    _epoch = 0;
    ref.onDispose(() => _disposed = true);
    return (status: CoachChatStatus.idle, pending: null, remaining: null);
  }

  /// Tải số lượt hỏi còn lại hôm nay — gọi khi mở màn, trước khi người chơi
  /// hỏi gì. Bỏ kết quả nếu đang gửi câu hỏi (phản hồi câu đó sẽ tự mang
  /// `remaining` mới hơn), hay nếu một câu đã xong việc trong lúc đang chờ
  /// (epoch đổi) — nuốt lỗi, giữ nguyên `remaining` cũ.
  Future<void> loadQuota() async {
    if (state.status == CoachChatStatus.sending) return;
    final epochAtStart = _epoch;
    int remaining;
    try {
      remaining = await ref.read(coachChatBackendProvider).remainingToday();
    } on Object {
      return;
    }
    if (_disposed) return;
    if (state.status == CoachChatStatus.sending) return;
    if (_epoch != epochAtStart) return;
    state = (status: state.status, pending: state.pending, remaining: remaining);
  }

  /// Gửi câu hỏi [question]. Không làm gì nếu: rỗng sau khi trim; dài hơn
  /// [coachChatMaxQuestion] đơn vị UTF-16 (R12); đang gửi câu khác; đã hết
  /// lượt hôm nay (`remaining == 0`); ngữ cảnh chưa sẵn sàng
  /// ([coachContextProvider] không phải `AsyncData`); hay chưa đăng nhập
  /// (repository null).
  Future<void> send(String question) async {
    final q = question.trim();
    final repo = ref.read(coachChatRepositoryProvider);
    final contextAsync = ref.read(coachContextProvider);
    if (q.isEmpty ||
        q.length > coachChatMaxQuestion ||
        state.status == CoachChatStatus.sending ||
        state.remaining == 0 ||
        contextAsync is! AsyncData<CoachContext> ||
        repo == null) {
      return;
    }

    final context = contextAsync.value;
    state = (status: CoachChatStatus.sending, pending: q, remaining: state.remaining);

    final history = coachChatHistory(
      await repo.recentTurns(coachChatHistoryTurns),
      insufficientText: Vi.coachChatInsufficient,
    );

    final backend = ref.read(coachChatBackendProvider);
    final askedAt = ref.read(nowProvider)();
    try {
      final answer = await backend.reply(context, history, q);
      _epoch++;
      // Lưu trước, bất kể màn đã rời đi hay chưa (R19, R20) — câu trả lời
      // không được mất chỉ vì người chơi đã sang màn khác.
      final answeredAt = ref.read(nowProvider)();
      await repo.addExchange(question: q, askedAt: askedAt, reply: answer.reply, answeredAt: answeredAt);
      if (_disposed) return;
      state = (status: CoachChatStatus.idle, pending: null, remaining: answer.remainingToday);
    } on Object catch (e) {
      _epoch++;
      if (_disposed) return;
      state = switch (e) {
        CoachChatQuotaExceeded() => (status: CoachChatStatus.idle, pending: null, remaining: 0),
        _ when e == AuthFailure.sessionExpired => (
            status: CoachChatStatus.idle,
            pending: null,
            remaining: state.remaining,
          ),
        // Lỗi khác (mất mạng, "truncated", 5xx...) — màn hình chỉ hiện câu
        // chung `Vi.coachChatError`, không bao giờ in nguyên văn lỗi.
        _ => (status: CoachChatStatus.failed, pending: q, remaining: state.remaining),
      };
    }
  }

  /// Gửi lại câu đang chờ sau khi gửi hỏng.
  Future<void> retry() async {
    if (state.status != CoachChatStatus.failed) return;
    final pending = state.pending;
    if (pending == null) return;
    await send(pending);
  }

  /// Xoá mọi lượt chat đã lưu trên máy của tài khoản này.
  Future<void> clear() async {
    final repo = ref.read(coachChatRepositoryProvider);
    if (repo == null) return;
    await repo.clear();
    if (_disposed) return;
    state = (status: CoachChatStatus.idle, pending: null, remaining: state.remaining);
  }
}
