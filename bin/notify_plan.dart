import 'dart:convert';
import 'dart:io';

import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/data/seed/seed_knowledge.dart';
import 'package:poolcoachai/domain/notifications/seed_fingerprint.dart';
import 'package:poolcoachai/server/notify_plan.dart' show notifyPlanCollections;
import 'package:poolcoachai/server/notify_plan_protocol.dart';

// Helper thông báo phía máy chủ, nói NDJSON qua stdin/stdout. Đây là nơi duy
// nhất ngoài lib/data/seed và upsert_seed.dart nạp seed.

/// Múi của tiến trình mà có đổi giờ trong một năm quanh hôm nay thì "giờ trên
/// tường" tính bằng `DateTime` sai: chạy với TZ=UTC.
bool processZoneHasDst() {
  final now = DateTime.now();
  final first = DateTime(now.year, now.month - 6, 15).timeZoneOffset;
  for (var i = -5; i <= 6; i++) {
    if (DateTime(now.year, now.month + i, 15).timeZoneOffset != first) {
      return true;
    }
  }
  return false;
}

Future<void> main(List<String> args) async {
  if (processZoneHasDst()) {
    stderr.writeln('Múi giờ tiến trình có đổi giờ — chạy với TZ=UTC');
    exit(2);
  }

  String handle(String line) => handleNotifyPlanLine(
    line,
    drills: seedDrills,
    knowledge: seedKnowledge,
  );

  if (args.contains('--self-test')) {
    final info = handle('{"v":1,"op":"info","reqId":"self-test-info"}');
    stdout.writeln(info);
    final plan = handle(
      jsonEncode({
        'v': 1,
        'op': 'plan',
        'reqId': 'self-test-plan',
        'userId': 'self-test',
        'nowUtc': DateTime.now().toUtc().toIso8601String(),
        'tz': 'UTC',
        'mode': 'due',
        'prefs': {
          'recommendation': true,
          'maintenance': true,
          'schedule': true,
          'streak': true,
        },
        'seen': null,
        'sentRecommendations': <Object?>[],
        'data': {
          for (final c in notifyPlanCollections) c: <Object?>[],
        },
      }),
    );
    stdout.writeln(plan);
    await stdout.flush();
    final ok =
        [info, plan].every((r) => (jsonDecode(r) as Map)['ok'] == true) &&
        (jsonDecode(info) as Map)['fingerprint'] ==
            seedFingerprint(drills: seedDrills, knowledge: seedKnowledge);
    exit(ok ? 0 : 1);
  }

  await for (final line
      in notifyPlanLines(stdin)) {
    if (line.trim().isEmpty) continue;
    stdout.writeln(handle(line));
    await stdout.flush();
  }
  await stdout.flush();
}
