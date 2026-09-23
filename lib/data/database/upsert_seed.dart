import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/converters.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart' as seed;
import 'package:poolcoachai/data/seed/seed_knowledge.dart' as seed;

/// Upsert all seed data into the database.
///
/// Runs inside a transaction to ensure atomicity. Overwrites by `id`
/// on every launch so that code corrections reach installed devices.
Future<void> upsertSeed(AppDatabase db) async {
  await db.transaction(() async {
    // Upsert drills
    for (final drill in seed.seedDrills) {
      await db.into(db.drillRows).insertOnConflictUpdate(toDrillRow(drill));
    }

    // Upsert knowledge articles
    for (final article in seed.seedKnowledge) {
      await db.into(db.knowledgeRows).insertOnConflictUpdate(toKnowledgeRow(article));
    }
  });
}
