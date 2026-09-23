import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/data/repositories/drift_repositories.dart';
import 'package:poolcoachai/data/repositories/drill_log_repository.dart';
import 'package:poolcoachai/data/repositories/seed_repositories.dart';

/// Repository providers — swap implementations by overriding these.
final drillRepositoryProvider = Provider<DrillRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftDrillRepository(db);
});

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftKnowledgeRepository(db);
});

final drillLogRepositoryProvider = Provider<DrillLogRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftDrillLogRepository(db);
});
