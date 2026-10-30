import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/remote/codecs/remote_fields.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/data/seed/seed_knowledge.dart';
import 'package:poolcoachai/server/notify_plan_protocol.dart';

void main() {
  Set<String> split(String s) => s.split(',').toSet();

  final fileFields = () {
    final raw = jsonDecode(
      File('deploy/directus/push_service_fields.json').readAsStringSync(),
    ) as Map<String, Object?>;
    return {for (final e in raw.entries) e.key: split(e.value! as String)};
  }();

  final info = jsonDecode(
    handleNotifyPlanLine(
      jsonEncode({'v': 1, 'op': 'info', 'reqId': 'i'}),
      drills: seedDrills,
      knowledge: seedKnowledge,
    ),
  ) as Map<String, Object?>;

  test(
    'quyền đọc của PushService khớp đúng trường helper xin (cộng user_created)',
    () {
      final fields = (info['fields']! as Map).cast<String, String>();
      final expected = <String, Set<String>>{
        for (final e in fields.entries) e.key: {...split(e.value), 'user_created'},
        'notification_settings': {
          ...split(info['settingsFields']! as String),
          'user_created',
        },
      };
      expect(fileFields.keys.toSet(), expected.keys.toSet());
      for (final e in expected.entries) {
        expect(fileFields[e.key], e.value, reason: e.key);
      }
    },
  );

  test('notification_settings khớp hằng số của app (cộng user_created)', () {
    expect(
      fileFields['notification_settings'],
      {...split(notificationSettingsRemoteFields), 'user_created'},
    );
  });

  test('mọi trường helper xin cho notification_settings nằm trong hằng số app', () {
    final appFields = split(notificationSettingsRemoteFields)..add('user_created');
    expect(appFields.containsAll(split(notifyPlanSettingsFields)), isTrue);
  });

  test('danh sách trường Player trong bootstrap.mjs khớp hằng số Dart', () {
    final boot = File('deploy/directus/bootstrap.mjs').readAsStringSync();
    String literal(String name) {
      final m = RegExp("const $name = '([^']*)'[.]split").firstMatch(boot);
      expect(m, isNotNull, reason: name);
      return m!.group(1)!;
    }

    expect(
      split(literal('notificationSettingsFields')),
      split(notificationSettingsRemoteFields),
    );
    expect(
      split(literal('pushDeliveryFields')),
      split(pushDeliveryRemoteFields),
    );
  });
}
