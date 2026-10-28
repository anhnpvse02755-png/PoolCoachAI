import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';

final tToday = DateTime(2026, 10, 28, 10);

DateTime tDay(int offset) => DateTime(2026, 10, 28 + offset);

Tournament tour(
  String id, {
  required DateTime start,
  DateTime? end,
  String? name,
  PoolGameType? gameType,
  String? location,
  String? resultNote,
  String? notes,
}) => Tournament(
  id: id,
  name: name ?? 'Giải $id',
  startDate: start,
  endDate: end,
  gameType: gameType,
  location: location,
  resultNote: resultNote,
  notes: notes,
);
