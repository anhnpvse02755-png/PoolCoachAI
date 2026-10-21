import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';

/// Tình huống sinh ngẫu nhiên hay lấy từ thư viện mẫu (spec C3).
enum CoachSource { generated, library }

/// Một thế bàn để người chơi chọn cú (spec mục 5). **Không có trường đáp án
/// nào**: đáp án luôn do `CoachJob` tính bằng Planner.
final class CoachSituation {
  const CoachSituation({
    required this.key,
    required this.topic,
    required this.source,
    required this.difficulty,
    required this.setup,
    this.seed,
    this.libraryId,
  });

  /// `gen-v1-{topic}-{difficulty}-{seed}` hoặc `lib:{id}` — ổn định giữa
  /// các máy, lưu trong bản ghi lần làm.
  final String key;
  final CoachTopic topic;
  final CoachSource source;
  final CoachDifficulty difficulty;
  final TableSetup setup;
  final int? seed;
  final String? libraryId;

  /// Bi phải chạm: 9 / 10 bi luôn là bi số nhỏ nhất.
  int get ball => setup.balls.map((b) => b.number).reduce((a, b) => a < b ? a : b);
}

/// Khoá của tình huống sinh ngẫu nhiên (spec mục 8.2).
String generatedKey(CoachTopic topic, CoachDifficulty difficulty, int seed) =>
    'gen-v1-${topic.name}-${difficulty.name}-$seed';

/// Khoá của tình huống thư viện.
String libraryKey(String id) => 'lib:$id';
