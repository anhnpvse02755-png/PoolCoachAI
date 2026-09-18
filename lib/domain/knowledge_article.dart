import 'package:poolcoachai/domain/skill_category.dart';

/// Một bài kiến thức.
///
/// Quan hệ với bài tập là hai chiều và **hỗ trợ, không phải phụ thuộc
/// cứng** — người chơi được đọc kiến thức độc lập, không cần mở khoá
/// qua bài tập nào.
class KnowledgeArticle {
  const KnowledgeArticle({
    required this.id,
    required this.cat,
    required this.title,
    required this.body,
    this.relatedDrillIds = const [],
  });

  final String id;
  final SkillCategory cat;
  final String title;
  final String body;
  final List<String> relatedDrillIds;
}
