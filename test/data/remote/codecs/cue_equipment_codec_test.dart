import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/remote/codecs/cue_equipment_codec.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/skill_category.dart';

DateTime plus7(DateTime utc) => utc.add(const Duration(hours: 7));

Map<String, Object?> cue([Map<String, Object?> over = const {}]) => {
  'id': 'c1',
  'name': 'Cơ của An',
  'type': 'playing',
  'weight_grams': 540,
  'shaft_brand': null,
  'tip_diameter_mm': 12.5,
  'tip_brand': null,
  'tip_hardness': 'medium',
  'butt_brand': null,
  'skill_categories': ['aiming'],
  'skill_categories_ext': null,
  'last_tip_maintenance': '2026-10-01',
  'tip_maintenance_due_date': '2026-10-20T00:00:00.000Z',
  'updated_at': '2026-10-13T03:00:00.000Z',
  'is_deleted': false,
  ...over,
};

void main() {
  test('cơ: ngày chỉ-ngày giữ nửa đêm; độ cứng lạ ném; is_deleted không phải bool ném', () {
    final r = cueEquipmentFromRemote(cue(), toLocal: plus7);
    expect(r.cue.type, CueType.playing);
    expect(r.cue.tipHardness, TipHardness.medium);
    expect(r.cue.skillCategories, [SkillCategory.aiming]);
    expect(r.cue.shaftDiameterMm, 12.5);
    expect(r.cue.lastTipMaintenance, DateTime(2026, 10, 1));
    expect(r.cue.tipMaintenanceDueDate, DateTime.utc(2026, 10, 20, 7));
    expect(r.cue.updatedAt, DateTime.utc(2026, 10, 13, 3));
    expect(r.isDeleted, isFalse);
    expect(
      () => cueEquipmentFromRemote(cue({'tip_hardness': 'rock'})),
      throwsFormatException,
    );
    expect(
      () => cueEquipmentFromRemote(cue({'is_deleted': 'false'})),
      throwsFormatException,
    );
  });
}
