import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/knowledge_lookup.dart';
import 'package:poolcoachai/domain/skill_category.dart';

KnowledgeArticle _a(
  String id,
  SkillCategory cat, [
  List<String> drills = const [],
]) => KnowledgeArticle(
  id: id,
  cat: cat,
  title: 'T$id',
  body: 'B',
  relatedDrillIds: drills,
);

void main() {
  group('articlesForDrill', () {
    test('trả mọi bài khai báo bài tập đó, giữ thứ tự', () {
      final articles = [
        _a('k1', SkillCategory.aiming, ['d1']),
        _a('k2', SkillCategory.bank),
        _a('k3', SkillCategory.aiming, ['d2', 'd1']),
      ];
      expect(articlesForDrill('d1', articles).map((a) => a.id), ['k1', 'k3']);
    });

    test('không bài nào nhắc tới thì rỗng', () {
      expect(articlesForDrill('d9', [_a('k1', SkillCategory.aiming)]), isEmpty);
    });
  });

  group('groupArticlesByCategory', () {
    test('nhóm theo thứ tự SkillCategory, bỏ nhóm rỗng', () {
      final groups = groupArticlesByCategory([
        _a('k1', SkillCategory.bank),
        _a('k2', SkillCategory.aiming),
        _a('k3', SkillCategory.bank),
      ]);
      expect(groups.map((g) => g.$1), [
        SkillCategory.aiming,
        SkillCategory.bank,
      ]);
      expect(groups[1].$2.map((a) => a.id), ['k1', 'k3']);
    });
  });
}
