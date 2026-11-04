import 'dart:convert';

import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/push_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PushRegistrationStore {
  Future<PushLease?> load(String userId);

  Future<void> save(PushLease lease);

  Future<void> forget(String userId);
}

class SharedPreferencesPushRegistrationStore implements PushRegistrationStore {
  static const _prefix = 'poolcoachai:push-registration:v1:';

  @override
  Future<PushLease?> load(String userId) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      '$_prefix$userId',
    );
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map ||
          value['deviceId'] is! String ||
          (value['deviceId'] as String).isEmpty ||
          value['kinds'] is! List ||
          value['until'] is! String) {
        return null;
      }
      final until = DateTime.tryParse(value['until'] as String);
      if (until == null) return null;
      final known = {
        for (final kind in NotificationKind.values) kind.name: kind,
      };
      final kinds = <NotificationKind>{};
      for (final name in value['kinds'] as List) {
        if (name is! String || !known.containsKey(name)) return null;
        kinds.add(known[name]!);
      }
      return PushLease(
        userId: userId,
        deviceId: value['deviceId'] as String,
        serverKinds: kinds,
        until: until,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(PushLease lease) async {
    await (await SharedPreferences.getInstance()).setString(
      '$_prefix${lease.userId}',
      jsonEncode({
        'deviceId': lease.deviceId,
        'kinds': [for (final kind in lease.serverKinds) kind.name],
        'until': lease.until.toIso8601String(),
      }),
    );
  }

  @override
  Future<void> forget(String userId) async {
    await (await SharedPreferences.getInstance()).remove('$_prefix$userId');
  }
}
