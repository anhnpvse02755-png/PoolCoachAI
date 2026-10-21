import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Các bài kiến thức khai báo [drillId] trong `relatedDrillIds`.
///
/// Quan hệ bài đọc → bài tập là nguồn duy nhất; chiều ngược lại suy ra
/// ở đây, không lưu thêm một bản thứ hai.
List<KnowledgeArticle> articlesForDrill(
  String drillId,
  List<KnowledgeArticle> articles,
) => articles.where((a) => a.relatedDrillIds.contains(drillId)).toList();

/// Gom bài theo nhóm kỹ năng, theo thứ tự [SkillCategory.values], bỏ nhóm
/// không có bài.
List<(SkillCategory, List<KnowledgeArticle>)> groupArticlesByCategory(
  List<KnowledgeArticle> articles,
) => [
  for (final cat in SkillCategory.values)
    if (articles.any((a) => a.cat == cat))
      (cat, articles.where((a) => a.cat == cat).toList()),
];
