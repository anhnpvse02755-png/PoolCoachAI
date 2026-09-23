import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/repository_providers.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/drill_log.dart';

/// Stream of all drills from the database.
final drillsProvider = StreamProvider<List<Drill>>((ref) {
  final repo = ref.watch(drillRepositoryProvider);
  return repo.watchAll();
});

/// Stream of all knowledge articles from the database.
final knowledgeProvider = StreamProvider<List<KnowledgeArticle>>((ref) {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return repo.watchAll();
});

/// Stream of all drill logs from the database.
final drillLogsProvider = StreamProvider<List<DrillLog>>((ref) {
  final repo = ref.watch(drillLogRepositoryProvider);
  return repo.watchAll();
});
