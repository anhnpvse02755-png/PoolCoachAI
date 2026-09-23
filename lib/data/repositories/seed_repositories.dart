import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';

/// Repository interface for drills — abstracts the storage backend.
abstract interface class DrillRepository {
  Stream<List<Drill>> watchAll();
}

/// Repository interface for knowledge articles — abstracts the storage backend.
abstract interface class KnowledgeRepository {
  Stream<List<KnowledgeArticle>> watchAll();
}
