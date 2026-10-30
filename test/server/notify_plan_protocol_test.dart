import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/remote/codecs/remote_fields.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/data/seed/seed_knowledge.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/seed_fingerprint.dart';
import 'package:poolcoachai/server/notify_plan.dart';
import 'package:poolcoachai/server/notify_plan_protocol.dart';

import '../support/push_fixtures.dart';

void main() {
  Map<String, Object?> call(Object? request) {
    final line = request is String ? request : jsonEncode(request);
    final reply = handleNotifyPlanLine(
      line,
      drills: seedDrills,
      knowledge: seedKnowledge,
    );
    expect(reply.contains('\n'), isFalse, reason: 'một dòng một trả lời');
    return jsonDecode(reply) as Map<String, Object?>;
  }

  Map<String, Object?> planRequest({
    Object? data,
    String tz = 'Asia/Ho_Chi_Minh',
    String mode = 'upcoming',
    String reqId = 'r1',
    Object? seen,
    Map<String, Object?>? prefs,
    String nowUtc = '2026-10-28T03:00:00.000Z',
  }) => {
    'v': 1,
    'op': 'plan',
    'reqId': reqId,
    'userId': 'u1',
    'nowUtc': nowUtc,
    'tz': tz,
    'mode': mode,
    'prefs':
        prefs ??
        {
          'recommendation': false,
          'maintenance': false,
          'schedule': false,
          'streak': true,
        },
    'seen': seen,
    'sentRecommendations': <Object?>[],
    'data': data ?? emptyRemoteData(),
  };

  Map<String, List<Map<String, Object?>>> twoDayData() => {
    ...emptyRemoteData(),
    'drill_logs': [
      drillLogRow(id: 'l1', drillId: 'd1', date: DateTime.utc(2026, 10, 27, 12)),
      drillLogRow(id: 'l2', drillId: 'd3', date: DateTime.utc(2026, 10, 26, 12)),
    ],
  };

  test('info: dấu vân tay của seed, bốn loại, trường đủ cho từng collection', () {
    final r = call({'v': 1, 'op': 'info', 'reqId': 'i'});
    expect(r['ok'], isTrue);
    expect(r['v'], notifyPlanProtocolVersion);
    expect(
      r['fingerprint'],
      seedFingerprint(drills: seedDrills, knowledge: seedKnowledge),
    );
    expect(r['kinds'], [
      'recommendation',
      'maintenance',
      'schedule',
      'streak',
    ]);
    final fields = r['fields'] as Map;
    expect(fields['pool_matches'], poolMatchRemoteFields);
    expect(fields, notifyPlanCollectionFields);
    expect(fields['bu_tests'], '$remoteTestFields,user_created');
    expect(fields['bu_drill_results'], '$remoteResultFields,user_created');
    expect(fields.keys, notifyPlanCollections);
    final settings = (r['settingsFields'] as String).split(',');
    expect(settings, contains('last_seen_cat'));
    expect(settings, contains('user_created'));
  });

  test('plan: items bằng planForUser cùng đầu vào (TzWallClock)', () {
    final r = call(planRequest(data: twoDayData()));
    expect(r['ok'], isTrue);
    expect(r['reqId'], 'r1');
    expect(r['v'], 1);
    expect(
      r['fingerprint'],
      seedFingerprint(drills: seedDrills, knowledge: seedKnowledge),
    );
    final expected = planForUser(
      NotifyPlanRequest(
        userId: 'u1',
        nowUtc: DateTime.utc(2026, 10, 28, 3),
        tz: 'Asia/Ho_Chi_Minh',
        mode: NotifyPlanMode.upcoming,
        prefs: const NotificationPrefs(
          recommendation: false,
          maintenance: false,
          schedule: false,
        ),
        seen: null,
        sentRecommendations: const [],
        data: twoDayData(),
      ),
      drills: seedDrills,
      knowledge: seedKnowledge,
      clock: TzWallClock('Asia/Ho_Chi_Minh'),
    );
    final items = r['items'] as List;
    expect(expected, hasLength(1));
    expect(items, hasLength(1));
    final e = expected.single;
    expect(items.single, {
      'id': e.local.id,
      'kind': 'streak',
      'key': e.local.key,
      'at': '2026-10-28T20:00:00.000',
      'atUtc': '2026-10-28T13:00:00.000Z',
      'validUntil': e.local.validUntil.toIso8601String(),
      'validUntilUtc': '2026-10-28T17:00:00.000Z',
      'title': e.local.title,
      'body': e.local.body,
      'payload': e.payload,
    });
  });

  test('plan due với dữ liệu rỗng: ok, danh sách items', () {
    final r = call(planRequest(mode: 'due'));
    expect(r['ok'], isTrue);
    expect(r['items'], isA<List>());
  });

  test('dòng không phải JSON: ok:false bad_json, không ném', () {
    for (final line in ['', 'xin chào', '{', '[1,2]', '"x"', 'null']) {
      final r = call(line);
      expect(r['ok'], isFalse, reason: line);
      expect(r['error'], 'bad_json', reason: line);
      expect(r['reqId'], isNull);
      expect(r['v'], 1);
    }
  });

  test('phiên bản lạ: unsupported_version; thiếu trường: bad_request; tz lạ: bad_tz', () {
    expect(call({'v': 2, 'op': 'info', 'reqId': 'x'}), {
      'v': 1,
      'reqId': 'x',
      'ok': false,
      'error': 'unsupported_version',
    });
    expect(call({'op': 'info', 'reqId': 'x'})['error'], 'bad_request');
    expect(call({'v': 1, 'op': 'lạ', 'reqId': 'x'})['error'], 'bad_request');

    final noUser = planRequest()..remove('userId');
    expect(call(noUser)['error'], 'bad_request');
    expect(call(planRequest(mode: 'sometimes'))['error'], 'bad_request');
    expect(call(planRequest(nowUtc: 'hôm qua'))['error'], 'bad_request');
    expect(
      call(planRequest(nowUtc: '2026-10-28T03:00:00'))['error'],
      'bad_request',
      reason: 'giờ không có Z không phải giờ UTC',
    );
    expect(
      call(planRequest(prefs: {'recommendation': true}))['error'],
      'bad_request',
    );

    final bad = call(planRequest(tz: 'Moon/Tranquility'));
    expect(bad['error'], 'bad_tz');
    expect(bad['reqId'], 'r1');
  });

  test('thiếu bất kỳ khoá nào trong bảy khoá data: bad_request (kể cả bu_*)', () {
    for (final c in notifyPlanCollections) {
      final data = emptyRemoteData()..remove(c);
      expect(call(planRequest(data: data))['error'], 'bad_request', reason: c);
    }
    final notList = {...emptyRemoteData(), 'bu_tests': 'x'};
    expect(call(planRequest(data: notList))['error'], 'bad_request');
    final notRow = <String, Object?>{
      ...emptyRemoteData(),
      'bu_tests': [1],
    };
    expect(call(planRequest(data: notRow))['error'], 'bad_request');
    expect(call(planRequest(data: 'x'))['error'], 'bad_request');
  });

  test('seen: nhóm lạ thành chưa thấy, không phải lỗi; seen hỏng là bad_request', () {
    final unknown = call(
      planRequest(
        seen: {
          'cat': 'nhomCuaBanSau',
          'drillId': 'd1',
          'atUtc': '2026-10-27T01:00:00.000Z',
        },
      ),
    );
    expect(unknown['ok'], isTrue);
    expect(call(planRequest(seen: {'cat': 'x'}))['error'], 'bad_request');
    expect(call(planRequest(seen: 'x'))['error'], 'bad_request');
  });

  test('dữ liệu hỏng: bad_data kèm tên collection', () {
    final data = {
      ...emptyRemoteData(),
      'timer_sessions': [
        <String, Object?>{'id': 1},
      ],
    };
    final r = call(planRequest(data: data));
    expect(r['ok'], isFalse);
    expect(r['error'], 'bad_data');
    expect(r['collection'], 'timer_sessions');
    expect(r['reqId'], 'r1');
  });

  test('dòng của người khác: bad_data', () {
    final data = {
      ...emptyRemoteData(),
      'drill_logs': [
        drillLogRow(
          id: 'l1',
          drillId: 'd1',
          date: DateTime.utc(2026, 10, 27, 12),
          userId: 'ai-do-khac',
        ),
      ],
    };
    final r = call(planRequest(data: data));
    expect(r['error'], 'bad_data');
    expect(r['collection'], 'drill_logs');
  });

  test('reqId được trả lại nguyên vẹn', () {
    const id = 'Req-ĐẶC-biệt/9 "quote"';
    expect(call({'v': 1, 'op': 'info', 'reqId': id})['reqId'], id);
    expect(call(planRequest(reqId: id))['reqId'], id);
    expect(call(planRequest(reqId: id, tz: 'Nope/Nope'))['reqId'], id);
    // reqId không phải chuỗi: trả null, không ném.
    expect(call({'v': 1, 'op': 'info', 'reqId': 5})['reqId'], isNull);
  });

  test('lỗi bất ngờ: internal kèm kiểu lỗi, không bao giờ kèm nội dung lỗi', () {
    final info = jsonEncode({'v': 1, 'op': 'info', 'reqId': 'i'});
    final r =
        jsonDecode(
              handleNotifyPlanLine(
                info,
                drills: _ThrowingList<Drill>(failAtIteration: 1),
                knowledge: seedKnowledge,
              ),
            )
            as Map;
    expect(r, {
      'v': 1,
      'reqId': 'i',
      'ok': false,
      'error': 'internal',
      'errorType': 'StateError',
    });
    expect(jsonEncode(r), isNot(contains(_secret)));
  });

  test('lỗi bất ngờ trong bộ lập: internal, reqId giữ nguyên', () {
    // Lần lặp đầu (dấu vân tay) qua được; bộ lập lặp lần hai thì ném.
    final reply = handleNotifyPlanLine(
      jsonEncode(
        planRequest(
          mode: 'due',
          prefs: {
            'recommendation': true,
            'maintenance': false,
            'schedule': false,
            'streak': false,
          },
        ),
      ),
      drills: _ThrowingList<Drill>(failAtIteration: 2),
      knowledge: seedKnowledge,
    );
    final r = jsonDecode(reply) as Map;
    expect(r['error'], 'internal');
    expect(r['errorType'], 'StateError');
    expect(r['reqId'], 'r1');
    expect(reply, isNot(contains(_secret)));
  });

  test('dấu vân tay tính một lần cho cùng một bộ seed', () {
    final drills = _ThrowingList<Drill>(failAtIteration: 1 << 30);
    for (var i = 0; i < 3; i++) {
      handleNotifyPlanLine(
        '{"v":1,"op":"info","reqId":"i"}',
        drills: drills,
        knowledge: seedKnowledge,
      );
    }
    expect(drills.iterations, 1);
  });

  test('byte hỏng UTF-8 trên đường vào: một dòng bad_json, không giết luồng', () async {
    final bytes = <int>[
      0xff, 0x0a, // byte hỏng, ngoài chuỗi JSON
      ...utf8.encode('{"v":1,"op":"info","reqId":"sau"}\n'),
    ];
    final lines = await notifyPlanLines(Stream.value(bytes)).toList();
    expect(lines, hasLength(2));
    final replies = [for (final l in lines) call(l)];
    expect(replies[0]['error'], 'bad_json');
    expect(replies[1]['ok'], isTrue);
    expect(replies[1]['reqId'], 'sau');
  });
}

const _secret = 'BÍ-MẬT-KHÔNG-ĐƯỢC-LỘ';

/// Danh sách đúng seed, nhưng lần lặp thứ [failAtIteration] ném StateError
/// (kèm nội dung bí mật để kiểm helper không lộ nội dung lỗi).
final class _ThrowingList<T> extends ListBase<T> {
  _ThrowingList({required this.failAtIteration});

  final int failAtIteration;
  int iterations = 0;

  List<T> get _inner => (seedDrills as List).cast<T>();

  @override
  Iterator<T> get iterator {
    iterations++;
    if (iterations == failAtIteration) throw StateError(_secret);
    return _inner.iterator;
  }

  @override
  int get length => _inner.length;

  @override
  set length(int newLength) => throw UnsupportedError('chỉ đọc');

  @override
  T operator [](int index) => _inner[index];

  @override
  void operator []=(int index, T value) => throw UnsupportedError('chỉ đọc');
}
