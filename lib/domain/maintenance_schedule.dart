import 'package:poolcoachai/domain/cue_equipment.dart';

/// Một thông báo bảo dưỡng cần đặt lịch. `at` là giờ địa phương (09:00).
class MaintenanceReminder {
  const MaintenanceReminder({
    required this.id,
    required this.cueId,
    required this.cueName,
    required this.daysBefore,
    required this.at,
  });

  final int id;
  final String cueId;
  final String cueName;
  final int daysBefore;
  final DateTime at;
}

/// Giờ nhắc trong ngày.
const maintenanceReminderHour = 9;

/// Nhắc trước hạn 7 ngày và đúng ngày hạn.
const maintenanceReminderDaysBefore = [7, 0];

/// Các thông báo còn lại của mọi đầu cơ có hạn bảo dưỡng, xếp theo thời gian.
///
/// Mọi thông báo bị thay thế trọn bộ mỗi lần cơ đổi, nên id chỉ cần khác
/// nhau trong một lần tính — lấy theo thứ tự.
List<MaintenanceReminder> computeMaintenanceSchedule(
  Iterable<CueEquipment> cues, {
  required DateTime now,
}) {
  final pending = <({CueEquipment cue, int daysBefore, DateTime at})>[];
  for (final cue in cues) {
    final due = cue.tipMaintenanceDueDate;
    if (due == null) continue;
    for (final daysBefore in maintenanceReminderDaysBefore) {
      final at = DateTime(
        due.year,
        due.month,
        due.day - daysBefore,
        maintenanceReminderHour,
      );
      if (at.isAfter(now)) {
        pending.add((cue: cue, daysBefore: daysBefore, at: at));
      }
    }
  }
  pending.sort((a, b) => a.at.compareTo(b.at));
  return [
    for (var i = 0; i < pending.length; i++)
      MaintenanceReminder(
        id: i + 1,
        cueId: pending[i].cue.id,
        cueName: pending[i].cue.name,
        daysBefore: pending[i].daysBefore,
        at: pending[i].at,
      ),
  ];
}
