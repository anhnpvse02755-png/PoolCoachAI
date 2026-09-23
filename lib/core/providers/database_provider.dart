import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/data/database/database.dart';

/// The singleton database instance.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
