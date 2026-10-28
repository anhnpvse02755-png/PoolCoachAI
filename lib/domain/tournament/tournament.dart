import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/roadmap/pace.dart';

/// Giới hạn của Giải đấu (spec giải đấu; độ dài tính theo ký tự Unicode).
abstract final class TournamentConstants {
  static const nameMaxLength = 80;
  static const locationMaxLength = 120;
  static const resultNoteMaxLength = 120;
  static const notesMaxLength = 500;
  static const roundLabelMaxLength = 40;

  /// Số ngày sau khi giải xong mà giải vẫn được chọn khi bắt đầu trận mới.
  static const recentDays = 7;
}

/// Trạng thái giải, tính từ ngày địa phương, không lưu.
enum TournamentStatus { sapToi, dangDienRa, daXong }

/// Một giải đấu người chơi tự ghi.
final class Tournament {
  const Tournament({
    required this.id,
    required this.name,
    required this.startDate,
    this.endDate,
    this.location,
    this.gameType,
    this.resultNote,
    this.notes,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final String? location;
  final PoolGameType? gameType;
  final String? resultNote;
  final String? notes;

  /// Ngày cuối của giải: ngày kết thúc, không có thì ngày bắt đầu.
  DateTime get lastDay => endDate ?? startDate;

  @override
  bool operator ==(Object other) =>
      other is Tournament &&
      other.id == id &&
      other.name == name &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.location == location &&
      other.gameType == gameType &&
      other.resultNote == resultNote &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    startDate,
    endDate,
    location,
    gameType,
    resultNote,
    notes,
  );

  @override
  String toString() =>
      'Tournament(id: $id, name: $name, startDate: $startDate, '
      'endDate: $endDate, location: $location, gameType: $gameType, '
      'resultNote: $resultNote, notes: $notes)';
}

/// Dữ liệu người chơi nhập, chưa có id.
final class TournamentDraft {
  const TournamentDraft({
    required this.name,
    required this.startDate,
    this.endDate,
    this.location,
    this.gameType,
    this.resultNote,
    this.notes,
  });

  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final String? location;
  final PoolGameType? gameType;
  final String? resultNote;
  final String? notes;
}

enum TournamentInputError {
  nameRequired,
  nameTooLong,
  endBeforeStart,
  locationTooLong,
  resultNoteTooLong,
  notesTooLong,
}

int _length(String s) => s.trim().runes.length;

/// Mọi lỗi của [d] (không chỉ lỗi đầu tiên). Chữ tuỳ chọn rỗng thì không lỗi.
Set<TournamentInputError> tournamentInputErrors(TournamentDraft d) {
  final errors = <TournamentInputError>{};
  final nameLength = _length(d.name);
  if (nameLength == 0) {
    errors.add(TournamentInputError.nameRequired);
  } else if (nameLength > TournamentConstants.nameMaxLength) {
    errors.add(TournamentInputError.nameTooLong);
  }
  final end = d.endDate;
  if (end != null && dateOnly(end).isBefore(dateOnly(d.startDate))) {
    errors.add(TournamentInputError.endBeforeStart);
  }
  final location = d.location;
  if (location != null &&
      _length(location) > TournamentConstants.locationMaxLength) {
    errors.add(TournamentInputError.locationTooLong);
  }
  final result = d.resultNote;
  if (result != null &&
      _length(result) > TournamentConstants.resultNoteMaxLength) {
    errors.add(TournamentInputError.resultNoteTooLong);
  }
  final notes = d.notes;
  if (notes != null && _length(notes) > TournamentConstants.notesMaxLength) {
    errors.add(TournamentInputError.notesTooLong);
  }
  return errors;
}

/// Trạng thái của [t] vào ngày [today], so theo ngày địa phương.
TournamentStatus tournamentStatus(Tournament t, DateTime today) {
  final day = dateOnly(today);
  if (day.isBefore(dateOnly(t.startDate))) return TournamentStatus.sapToi;
  if (day.isAfter(dateOnly(t.lastDay))) return TournamentStatus.daXong;
  return TournamentStatus.dangDienRa;
}

/// Chữ đã cắt khoảng trắng, hoặc null khi null hay trống.
String? trimmedOrNull(String? raw) {
  final trimmed = raw?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Nhãn vòng hợp lệ: null hoặc trống là được, còn lại tối đa 40 ký tự.
bool roundLabelValid(String? label) =>
    label == null || _length(label) <= TournamentConstants.roundLabelMaxLength;
