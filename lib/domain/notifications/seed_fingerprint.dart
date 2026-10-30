import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';

/// Dấu vân tay của bộ bài tập và bài đọc: đổi thứ tự, tên, cấp, ngưỡng,
/// target hay liên kết bài đọc thì dấu đổi; đổi bước tập hay mục tiêu
/// chữ thì dấu giữ nguyên.
String seedFingerprint({
  required List<Drill> drills,
  required List<KnowledgeArticle> knowledge,
}) {
  String milli(num? x) => x == null ? '' : (x * 1000).round().toString();
  final lines = <String>[
    for (final d in drills)
      'd|${d.id}|${d.cat.name}|${d.name}|${d.level}|'
          '${milli(d.passThreshold)}|${milli(d.target)}',
    for (final k in knowledge)
      'k|${k.id}|${k.cat.name}|${k.relatedDrillIds.join(',')}',
  ];
  final hash = fnv32(lines.join('\n'));
  return 'v1-${drills.length}-${knowledge.length}-'
      '${hash.toRadixString(16).padLeft(8, '0')}';
}
