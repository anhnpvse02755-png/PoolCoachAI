import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Dữ liệu và bộ chứa provider dùng chung cho mọi widget test.
///
/// Widget test không được chạm vào SQLite thật: mỗi test tự dựng dữ
/// liệu của mình rồi ghi đè ba stream nguồn. Gom về một chỗ để thêm
/// một trường vào [Drill] không phải sửa bốn file test.

final testDrills = <Drill>[
  const Drill(
    id: 'd1',
    cat: SkillCategory.aiming,
    name: 'Đường thẳng cơ bản',
    level: 1,
    unit: 'lần trúng / 10',
    passThreshold: 0.8,
    goal: 'Đánh thẳng bi cái.',
    steps: ['Bước 1', 'Bước 2'],
  ),
];

final testKnowledge = <KnowledgeArticle>[
  const KnowledgeArticle(
    id: 'k1',
    cat: SkillCategory.aiming,
    title: 'Nguyên lý bi ảo',
    body: 'Thân bài kiến thức về bi ảo.',
    relatedDrillIds: ['d1'],
  ),
  const KnowledgeArticle(
    id: 'k2',
    cat: SkillCategory.bank,
    title: 'Cân bi một băng',
    body: 'Thân bài kiến thức về cân bi.',
  ),
];

/// Bộ chứa provider đã ghi đè ba stream nguồn bằng dữ liệu test.
/// Hôm nay cố định cho widget test. Đồng hồ máy làm test xanh hôm nay,
/// đỏ vào đúng nửa đêm.
final testToday = DateTime(2026, 9, 22, 10, 0);

ProviderContainer testContainer({
  List<Drill>? drills,
  List<KnowledgeArticle>? knowledge,
  List<DrillLog>? logs,
  DateTime? now,
}) {
  return ProviderContainer(
    overrides: [
      nowProvider.overrideWithValue(() => now ?? testToday),
      drillsProvider.overrideWith((ref) => Stream.value(drills ?? testDrills)),
      knowledgeProvider
          .overrideWith((ref) => Stream.value(knowledge ?? testKnowledge)),
      drillLogsProvider
          .overrideWith((ref) => Stream.value(logs ?? const <DrillLog>[])),
    ],
  );
}
