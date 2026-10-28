import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/async_gate.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/data/repositories/tournament_repository.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';
import 'package:poolcoachai/domain/tournament/tournament_goal.dart';
import 'package:poolcoachai/domain/tournament/tournament_lists.dart';
import 'package:poolcoachai/domain/tournament/tournament_results.dart';
import 'package:uuid/uuid.dart';

/// Giải đấu của người đang đăng nhập; null khi chưa đăng nhập.
final tournamentRepositoryProvider = Provider<TournamentRepository?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return TournamentRepository(
    ref.watch(appDatabaseProvider),
    userId: userId,
    now: ref.watch(nowProvider),
    newId: const Uuid().v4,
  );
});

final tournamentsProvider = StreamProvider<List<Tournament>>((ref) {
  final repo = ref.watch(tournamentRepositoryProvider);
  return repo == null ? Stream.value(const []) : repo.watchAll();
});

final tournamentsByIdProvider = Provider<AsyncValue<Map<String, Tournament>>>((
  ref,
) {
  final tournaments = ref.watch(tournamentsProvider);
  final blocked = gate<Map<String, Tournament>>([tournaments]);
  if (blocked != null) return blocked;
  return AsyncData({for (final t in tournaments.value!) t.id: t});
});

final tournamentGroupsProvider = Provider<AsyncValue<TournamentGroups>>((ref) {
  final tournaments = ref.watch(tournamentsProvider);
  final today = ref.watch(nowProvider)();
  final blocked = gate<TournamentGroups>([tournaments]);
  if (blocked != null) return blocked;
  return AsyncData(groupTournaments(tournaments.value!, today));
});

final featuredTournamentProvider = Provider<AsyncValue<FeaturedTournament>>((
  ref,
) {
  final tournaments = ref.watch(tournamentsProvider);
  final today = ref.watch(nowProvider)();
  final blocked = gate<FeaturedTournament>([tournaments]);
  if (blocked != null) return blocked;
  return AsyncData(featuredTournament(tournaments.value!, today));
});

/// Trạng thái của một giải, lấy từ chính phép chia nhóm: màn chi tiết và danh
/// sách thấy cùng một trạng thái, không tự tính lại theo giờ khác. Null khi
/// mã giải không còn.
final tournamentStatusProvider =
    Provider.family<AsyncValue<TournamentStatus?>, String>((ref, id) {
      final groups = ref.watch(tournamentGroupsProvider);
      return groups.whenData((g) {
        if (g.dangDienRa.any((t) => t.id == id)) {
          return TournamentStatus.dangDienRa;
        }
        if (g.sapToi.any((t) => t.id == id)) return TournamentStatus.sapToi;
        if (g.daXong.any((t) => t.id == id)) return TournamentStatus.daXong;
        return null;
      });
    });

final tournamentSummariesProvider =
    Provider<AsyncValue<Map<String, TournamentSummary>>>((ref) {
      final tournaments = ref.watch(tournamentsProvider);
      final matches = ref.watch(matchesProvider);
      final blocked = gate<Map<String, TournamentSummary>>([
        tournaments,
        matches,
      ]);
      if (blocked != null) return blocked;
      return AsyncData(
        summariesByTournament(tournaments.value!, matches.value!),
      );
    });

final tournamentComparisonProvider = Provider<AsyncValue<TournamentComparison>>(
  (ref) {
    final tournaments = ref.watch(tournamentsProvider);
    final matches = ref.watch(matchesProvider);
    final blocked = gate<TournamentComparison>([tournaments, matches]);
    if (blocked != null) return blocked;
    return AsyncData(compareTournamentPlay(matches.value!, tournaments.value!));
  },
);

/// Null khi giải không còn.
final tournamentViewProvider =
    Provider.family<AsyncValue<TournamentView?>, String>((ref, id) {
      final tournaments = ref.watch(tournamentsProvider);
      final matches = ref.watch(matchesProvider);
      final blocked = gate<TournamentView?>([tournaments, matches]);
      if (blocked != null) return blocked;
      return AsyncData(tournamentView(id, tournaments.value!, matches.value!));
    });

/// Giải mà mục tiêu hiện tại trỏ tới (qua [linkedTournament]).
final linkedTournamentProvider = Provider<AsyncValue<Tournament?>>((ref) {
  final goal = ref.watch(goalProvider);
  final tournaments = ref.watch(tournamentsProvider);
  final blocked = gate<Tournament?>([goal, tournaments]);
  if (blocked != null) return blocked;
  return AsyncData(linkedTournament(goal.value?.goal, tournaments.value!));
});

/// Trạng thái nút "Chuẩn bị cho giải này" cùng loại mục tiêu hiện tại (để hộp
/// thoại "đổi mục tiêu?" gọi tên nó). Cả hai lấy từ nguồn đã qua cổng: đọc
/// thẳng goalProvider có thể lộ mục tiêu của tài khoản trước khi đang tải lại.
typedef TournamentGoalView = ({
  TournamentGoalState state,
  GoalKind? currentKind,
});

/// Null khi mã giải không còn.
final tournamentGoalStateProvider =
    Provider.family<AsyncValue<TournamentGoalView?>, String>((ref, id) {
      final goal = ref.watch(goalProvider);
      final tournaments = ref.watch(tournamentsProvider);
      final today = ref.watch(nowProvider)();
      final blocked = gate<TournamentGoalView?>([goal, tournaments]);
      if (blocked != null) return blocked;
      final t = tournaments.value!.where((t) => t.id == id).firstOrNull;
      if (t == null) return const AsyncData(null);
      final current = goal.value?.goal;
      return AsyncData((
        state: tournamentGoalState(
          t,
          goal: current,
          live: tournaments.value!,
          today: today,
        ),
        currentKind: current?.kind,
      ));
    });

/// Những gì hộp thoại bắt đầu trận cần: cơ, trận (để chọn cơ mặc định) và các
/// giải. Qua cổng: chưa đủ thì đang tải, không thay bằng danh sách rỗng (cơ mặc
/// định và danh sách giải sẽ sai).
typedef StartMatchInputs = ({
  List<CueEquipment> cues,
  List<PoolMatch> matches,
  Map<String, Tournament> tournamentsById,
});

final startMatchInputsProvider = Provider<AsyncValue<StartMatchInputs>>((ref) {
  final cues = ref.watch(cueEquipmentProvider);
  final matches = ref.watch(matchesProvider);
  final tournaments = ref.watch(tournamentsProvider);
  final blocked = gate<StartMatchInputs>([cues, matches, tournaments]);
  if (blocked != null) return blocked;
  return AsyncData((
    cues: cues.value!,
    matches: matches.value!,
    tournamentsById: {for (final t in tournaments.value!) t.id: t},
  ));
});
