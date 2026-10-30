import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';

/// Phiên bản logic gợi ý. TĂNG KHI đổi logic chọn gợi ý (recommendation
/// baseline, thứ tự ứng viên, luật chọn bài) hoặc chữ nhắc tiếng Việt của
/// gợi ý. Thiết bị và máy chủ so dấu vân tay để biết hai bên có lập cùng một
/// gợi ý không; không tăng thì hai bản lệch nhau mà dấu vẫn trùng, máy chủ
/// gửi gợi ý khác với app.
const recommendationLogicVersion = 1;

/// Dấu vân tay của bộ bài tập và bài đọc cùng [recommendationLogicVersion]:
/// đổi thứ tự, tên, cấp, ngưỡng, target, liên kết bài đọc hay phiên bản
/// logic thì dấu đổi; đổi bước tập hay mục tiêu chữ thì dấu giữ nguyên.
String seedFingerprint({
  required List<Drill> drills,
  required List<KnowledgeArticle> knowledge,
  int logicVersion = recommendationLogicVersion,
}) {
  String milli(num? x) => x == null ? '' : (x * 1000).round().toString();
  final lines = <String>[
    'r|$logicVersion',
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
