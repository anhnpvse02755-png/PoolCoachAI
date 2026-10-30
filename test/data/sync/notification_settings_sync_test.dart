import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/notifications/notification_prefs_store.dart';
import 'package:poolcoachai/data/notifications/notification_settings_meta_store.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/sync/notification_settings_sync.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';
import '../../support/fake_notification_settings_stores.dart';
import '../../support/fake_recommendation_seen_store.dart';

void main() {
  late FakeDirectus server;
  late FakeAuthRepository auth;
  late FakeNotificationPrefsStore prefs;
  late FakeRecommendationSeenStore seen;
  late FakeNotificationSettingsMetaStore meta;
  late List<({String user, NotificationPrefs? prefs, SeenRecommendation? seen})>
  adopted;
  final now = DateTime.utc(2026, 10, 30, 12);
  final older = DateTime.utc(2026, 10, 30, 8);
  final newer = DateTime.utc(2026, 10, 30, 10);

  NotificationSettingsSyncService build({
    String? Function()? timeZone,
    NotificationPrefsStore? prefsStore,
    Duration retryEvery = const Duration(seconds: 30),
  }) {
    final s = NotificationSettingsSyncService(
      auth: auth,
      retryEvery: retryEvery,
      api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
      prefs: prefsStore ?? prefs,
      seen: seen,
      meta: meta,
      now: () => now,
      timeZone: timeZone ?? () => null,
      onAdopted: (u, {prefs, seen}) =>
          adopted.add((user: u, prefs: prefs, seen: seen)),
    );
    addTearDown(s.dispose);
    return s;
  }

  Map<String, Object?> row({
    bool recommendation = true,
    bool maintenance = true,
    bool schedule = true,
    bool streak = true,
    DateTime? prefsAt,
    String? cat,
    String? drill,
    DateTime? seenAt,
    String? tz,
  }) => {
    'id': 'u1',
    'recommendation': recommendation,
    'maintenance': maintenance,
    'schedule': schedule,
    'streak': streak,
    'prefs_updated_at': prefsAt?.toIso8601String(),
    'last_seen_cat': cat,
    'last_seen_drill_id': drill,
    'last_seen_at': seenAt?.toIso8601String(),
    'timezone': tz,
  };

  List<Map<String, Object?>>? remote;
  void serve() {
    server.routes['GET /items/notification_settings'] = (_) =>
        FakeDirectus.ok(remote ?? const []);
    server.routes['POST /items/notification_settings'] = (req) {
      remote = [jsonDecode(req.body) as Map<String, Object?>];
      return FakeDirectus.ok(remote!.first);
    };
    server.routes['PATCH /items/notification_settings/u1'] = (req) {
      final patch = jsonDecode(req.body) as Map<String, Object?>;
      remote = [
        {...remote!.first, ...patch},
      ];
      return FakeDirectus.ok(remote!.first);
    };
  }

  setUp(() {
    server = FakeDirectus();
    auth = FakeAuthRepository.signedIn();
    prefs = FakeNotificationPrefsStore();
    seen = FakeRecommendationSeenStore();
    meta = FakeNotificationSettingsMetaStore();
    adopted = [];
    remote = null;
    serve();
  });

  test(
    'lần đầu, máy chủ chưa có dòng: đẩy cài đặt và cặp đã thấy của bản cục bộ '
    'cũ (P6a) lên một lần',
    () async {
      prefs.saved['u1'] = const NotificationPrefs(streak: false);
      seen.saved['u1'] = SeenRecommendation(
        cat: SkillCategory.kick,
        drillId: 'd9',
        at: older,
      );
      final s = build(timeZone: () => 'Asia/Ho_Chi_Minh');

      expect(await s.syncNow(), SyncOutcome.done);

      final body = FakeDirectus.body(
        server.sent('POST', '/items/notification_settings').single,
      );
      expect(body['id'], 'u1');
      expect(body['streak'], false);
      expect(body['recommendation'], true);
      expect(body['prefs_updated_at'], now.toIso8601String());
      expect(body['last_seen_cat'], 'kick');
      expect(body['last_seen_drill_id'], 'd9');
      expect(body['last_seen_at'], older.toIso8601String());
      expect(body['timezone'], 'Asia/Ho_Chi_Minh');
      expect(meta.saved['u1']?.prefsDirty, false);
      expect(meta.saved['u1']?.seenDirty, false);

      expect(await s.syncNow(), SyncOutcome.done);
      expect(server.sent('POST', '/items/notification_settings'), hasLength(1));
      expect(adopted, isEmpty);
    },
  );

  test(
    'máy chủ đã có dòng, máy này chưa từng đồng bộ: nhận bản máy chủ, gọi '
    'onAdopted',
    () async {
      remote = [
        row(
          streak: false,
          prefsAt: older,
          cat: 'aiming',
          drill: 'd2',
          seenAt: older,
        ),
      ];
      final s = build();

      expect(await s.syncNow(), SyncOutcome.done);

      expect(prefs.saved['u1'], const NotificationPrefs(streak: false));
      expect(seen.saved['u1']?.drillId, 'd2');
      expect(meta.saved['u1']?.prefsUpdatedAt, older);
      expect(
        adopted.map((a) => a.prefs),
        contains(const NotificationPrefs(streak: false)),
      );
      expect(adopted.map((a) => a.seen?.drillId), contains('d2'));
      expect(server.sent('POST', '/items/notification_settings'), isEmpty);
      expect(server.sent('PATCH', '/items/notification_settings/u1'), isEmpty);
    },
  );

  test(
    'đổi công tắc khi mất mạng rồi có mạng: PATCH đúng nhóm prefs với '
    'prefs_updated_at mới',
    () async {
      remote = [row(prefsAt: older)];
      meta.saved['u1'] = NotificationSettingsMeta(prefsUpdatedAt: older);
      final s = build();
      expect(await s.syncNow(), SyncOutcome.done);

      prefs.saved['u1'] = const NotificationPrefs(maintenance: false);
      server.offline = true;
      await s.localPrefsChanged('u1');
      expect(await s.syncNow(), SyncOutcome.offline);
      expect(meta.saved['u1']?.prefsDirty, true);
      server.offline = false;

      expect(await s.syncNow(), SyncOutcome.done);
      final patch = FakeDirectus.body(
        server.sent('PATCH', '/items/notification_settings/u1').single,
      );
      expect(patch['maintenance'], false);
      expect(patch['prefs_updated_at'], now.toIso8601String());
      expect(patch.containsKey('last_seen_cat'), false);
      expect(meta.saved['u1']?.prefsDirty, false);
      expect(adopted, isEmpty);
    },
  );

  test(
    'hai máy: bản prefs mới hơn thắng; cặp đã thấy mới hơn thắng, độc lập với '
    'prefs',
    () async {
      // Máy chủ: prefs mới hơn, cặp đã thấy cũ hơn.
      remote = [
        row(
          schedule: false,
          prefsAt: newer,
          cat: 'aiming',
          drill: 'dOld',
          seenAt: older,
        ),
      ];
      meta.saved['u1'] = NotificationSettingsMeta(
        prefsUpdatedAt: older,
        prefsDirty: true,
      );
      prefs.saved['u1'] = const NotificationPrefs(streak: false);
      seen.saved['u1'] = SeenRecommendation(
        cat: SkillCategory.kick,
        drillId: 'dNew',
        at: newer,
      );
      final s = build();

      expect(await s.syncNow(), SyncOutcome.done);

      // Prefs: máy chủ thắng.
      expect(prefs.saved['u1'], const NotificationPrefs(schedule: false));
      // Cặp đã thấy: máy này thắng, và chỉ nhóm này được PATCH.
      final patch = FakeDirectus.body(
        server.sent('PATCH', '/items/notification_settings/u1').single,
      );
      expect(patch['last_seen_drill_id'], 'dNew');
      expect(patch.containsKey('streak'), false);
      expect(meta.saved['u1']?.prefsDirty, false);
    },
  );

  test('không có gì khác: không PATCH, không ghi kho (đếm request)', () async {
    remote = [row(prefsAt: older, cat: 'aiming', drill: 'd2', seenAt: older)];
    final s = build();
    await s.syncNow();
    final saves = prefs.saves + meta.saves;
    final requests = server.requests.length;

    await s.syncNow();
    await s.syncNow();
    await s.syncNow();

    expect(server.sent('PATCH', '/items/notification_settings/u1'), isEmpty);
    expect(server.sent('POST', '/items/notification_settings'), isEmpty);
    expect(prefs.saves + meta.saves, saves);
    // Mỗi lượt chỉ một GET.
    expect(server.requests.length, requests + 3);
  });

  test('nhận bản máy chủ không làm bẩn lại (không đẩy ngược)', () async {
    remote = [row(streak: false, prefsAt: newer)];
    meta.saved['u1'] = NotificationSettingsMeta(prefsUpdatedAt: older);
    final s = build();
    await s.syncNow();
    await s.syncNow();

    expect(meta.saved['u1']?.prefsDirty, false);
    expect(meta.saved['u1']?.prefsUpdatedAt, newer);
    expect(server.sent('PATCH', '/items/notification_settings/u1'), isEmpty);
  });

  test('đổi tài khoản giữa lượt: kết quả của u1 không ghi vào u2', () async {
    remote = [row(streak: false, prefsAt: older)];
    final gate = Completer<void>();
    server.routes['GET /items/notification_settings'] = (_) async {
      await gate.future;
      return FakeDirectus.ok(remote);
    };
    final s = build();
    final pending = s.syncNow();
    await pumpEventQueue();
    auth.emit(const SignedIn(userId: 'u2', displayName: 'B'));
    gate.complete();

    expect(await pending, SyncOutcome.signedOut);
    expect(prefs.saved, isEmpty);
    expect(seen.saved, isEmpty);
    expect(meta.saved, isEmpty);
    expect(adopted, isEmpty);
    expect(server.sent('POST', '/items/notification_settings'), isEmpty);
  });

  test('RECORD_NOT_UNIQUE khi tạo (máy khác vừa tạo): đọc lại rồi gộp', () async {
    var gets = 0;
    server.routes['GET /items/notification_settings'] = (_) {
      gets++;
      return FakeDirectus.ok(
        gets == 1 ? const [] : [row(streak: false, prefsAt: newer)],
      );
    };
    server.routes['POST /items/notification_settings'] = (_) =>
        FakeDirectus.error(400, 'RECORD_NOT_UNIQUE');
    final s = build();

    expect(await s.syncNow(), SyncOutcome.done);

    expect(gets, 2);
    expect(prefs.saved['u1'], const NotificationPrefs(streak: false));
    expect(adopted.first.prefs, const NotificationPrefs(streak: false));
  });

  test('start() tạo dòng ngay khi đã đăng nhập', () async {
    final s = build();
    s.start();
    await pumpEventQueue();
    expect(server.sent('POST', '/items/notification_settings'), hasLength(1));
  });

  group('vòng sửa 1', () {
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 150));

    test(
      'A: cài đặt bẩn còn từ phiên trước, mở app khi mất mạng, có mạng lại: '
      'PATCH trong một nhịp thử lại',
      () async {
        remote = [row(prefsAt: older)];
        meta.saved['u1'] = NotificationSettingsMeta(
          prefsUpdatedAt: newer,
          prefsDirty: true,
        );
        prefs.saved['u1'] = const NotificationPrefs(maintenance: false);
        server.offline = true;
        final s = build(retryEvery: const Duration(milliseconds: 20));
        s.start();
        await settle();
        server.offline = false;
        await settle();
        final patch = server.sent('PATCH', '/items/notification_settings/u1');
        expect(patch, isNotEmpty);
        expect(FakeDirectus.body(patch.first)['maintenance'], false);
      },
    );

    test(
      'A2: chưa có dòng, đăng nhập lần đầu khi mất mạng, có mạng lại: POST',
      () async {
        server.offline = true;
        final s = build(retryEvery: const Duration(milliseconds: 20));
        s.start();
        await settle();
        server.offline = false;
        await settle();
        expect(server.sent('POST', '/items/notification_settings'), isNotEmpty);
      },
    );

    test(
      'B: đổi công tắc trong lúc một lượt đang nhận bản máy chủ: giữ lựa chọn '
      'và PATCH sau đó',
      () async {
        remote = [row(prefsAt: newer)];
        meta.saved['u1'] = NotificationSettingsMeta(prefsUpdatedAt: older);
        final gated = _GatedPrefsStore(prefs);
        final s = build(prefsStore: gated);
        final pass = s.syncNow();
        await pumpEventQueue();
        // Người chơi tắt công tắc khi lượt đang chờ.
        prefs.saved['u1'] = const NotificationPrefs(maintenance: false);
        await s.localPrefsChanged('u1');
        gated.gate.complete();
        await pass;

        expect(prefs.saved['u1'], const NotificationPrefs(maintenance: false));
        expect(adopted.where((a) => a.prefs != null), isEmpty);
        expect(meta.saved['u1']?.prefsDirty, true);

        await s.syncNow();
        final patch = FakeDirectus.body(
          server.sent('PATCH', '/items/notification_settings/u1').single,
        );
        expect(patch['maintenance'], false);
        expect(patch['prefs_updated_at'], now.toIso8601String());
      },
    );

    test(
      'M6: đổi công tắc trong lúc PATCH đang bay: cờ bẩn không bị xoá',
      () async {
        remote = [row(prefsAt: older)];
        meta.saved['u1'] = NotificationSettingsMeta(
          prefsUpdatedAt: DateTime.utc(2026, 10, 30, 9),
          prefsDirty: true,
        );
        prefs.saved['u1'] = const NotificationPrefs(streak: false);
        final hold = Completer<void>();
        server.routes['PATCH /items/notification_settings/u1'] = (_) async {
          await hold.future;
          return FakeDirectus.ok(remote!.first);
        };
        final s = build();
        final pass = s.syncNow();
        await pumpEventQueue();
        prefs.saved['u1'] = const NotificationPrefs(schedule: false);
        await s.localPrefsChanged('u1');
        hold.complete();
        await pass;
        expect(meta.saved['u1']?.prefsDirty, true);
        expect(meta.saved['u1']?.prefsUpdatedAt, now);
      },
    );

    test(
      'M7: đổi cặp đã thấy trong lúc PATCH đang bay: cờ bẩn không bị xoá',
      () async {
        remote = [
          row(prefsAt: older, cat: 'aiming', drill: 'd1', seenAt: older),
        ];
        meta.saved['u1'] = NotificationSettingsMeta(
          prefsUpdatedAt: older,
          seenDirty: true,
        );
        seen.saved['u1'] = SeenRecommendation(
          cat: SkillCategory.kick,
          drillId: 'd2',
          at: newer,
        );
        final hold = Completer<void>();
        server.routes['PATCH /items/notification_settings/u1'] = (_) async {
          await hold.future;
          return FakeDirectus.ok(remote!.first);
        };
        final s = build();
        final pass = s.syncNow();
        await pumpEventQueue();
        seen.saved['u1'] = SeenRecommendation(
          cat: SkillCategory.kick,
          drillId: 'd3',
          at: now,
        );
        await s.localSeenChanged('u1');
        hold.complete();
        await pass;
        expect(meta.saved['u1']?.seenDirty, true);
      },
    );

    test(
      'R-F18: cùng cặp trong một ngày: không PATCH; qua mốc 08:00: đúng một '
      'PATCH (P→Q→P)',
      () async {
        final p1 = DateTime(2026, 10, 29, 20);
        remote = [
          row(prefsAt: older, cat: 'kick', drill: 'dP', seenAt: p1.toUtc()),
        ];
        meta.saved['u1'] = NotificationSettingsMeta(prefsUpdatedAt: older);
        seen.saved['u1'] = SeenRecommendation(
          cat: SkillCategory.kick,
          drillId: 'dP',
          at: DateTime(2026, 10, 29, 22),
        );
        final s = build();
        await s.syncNow();
        expect(
          server.sent('PATCH', '/items/notification_settings/u1'),
          isEmpty,
          reason: 'cùng ngày, chưa qua 08:00',
        );

        // Q được gửi lúc 08:00 ngày sau; 09:00 người chơi thấy lại P.
        seen.saved['u1'] = SeenRecommendation(
          cat: SkillCategory.kick,
          drillId: 'dP',
          at: DateTime(2026, 10, 30, 9),
        );
        await s.syncNow();
        await s.syncNow();
        final patches = server.sent('PATCH', '/items/notification_settings/u1');
        expect(patches, hasLength(1));
        expect(
          DateTime.parse(
            FakeDirectus.body(patches.single)['last_seen_at']! as String,
          ).isAtSameMomentAs(DateTime(2026, 10, 30, 9)),
          true,
        );

        // Lại thấy P lúc 15:00 cùng ngày: không PATCH thêm.
        seen.saved['u1'] = SeenRecommendation(
          cat: SkillCategory.kick,
          drillId: 'dP',
          at: DateTime(2026, 10, 30, 15),
        );
        await s.syncNow();
        expect(
          server.sent('PATCH', '/items/notification_settings/u1'),
          hasLength(1),
        );
      },
    );

    test('M11: nhịp thử lại chạy khi còn bẩn rồi dừng khi sạch', () async {
      remote = [row(prefsAt: older)];
      meta.saved['u1'] = NotificationSettingsMeta(
        prefsUpdatedAt: newer,
        prefsDirty: true,
      );
      final s = build(retryEvery: const Duration(milliseconds: 20));
      server.routes['PATCH /items/notification_settings/u1'] = (_) =>
          FakeDirectus.error(500, 'INTERNAL_SERVER_ERROR');
      s.start();
      await settle();
      final tries = server.sent('PATCH', '/items/notification_settings/u1');
      expect(tries.length, greaterThan(1));
      serve();
      await settle();
      final after = server.requests.length;
      await settle();
      expect(server.requests.length, after, reason: 'sạch thì ngừng thử');
    });

    test(
      'M12: PATCH timezone khi timeZone() khác null và khác bản máy chủ',
      () async {
        remote = [row(prefsAt: older, tz: 'UTC')];
        meta.saved['u1'] = NotificationSettingsMeta(prefsUpdatedAt: older);
        final s = build(timeZone: () => 'Asia/Ho_Chi_Minh');
        await s.syncNow();
        final patch = FakeDirectus.body(
          server.sent('PATCH', '/items/notification_settings/u1').single,
        );
        expect(patch, {'timezone': 'Asia/Ho_Chi_Minh'});
        await s.syncNow();
        expect(
          server.sent('PATCH', '/items/notification_settings/u1'),
          hasLength(1),
        );
      },
    );

    test('localPrefsChanged gọi syncNow sau start(), không gọi trước', () async {
      remote = [row(prefsAt: older)];
      meta.saved['u1'] = NotificationSettingsMeta(prefsUpdatedAt: older);
      final s = build();
      await s.localPrefsChanged('u1');
      await pumpEventQueue();
      expect(server.requests, isEmpty);

      s.start();
      await pumpEventQueue();
      server.requests.clear();
      await s.localPrefsChanged('u1');
      await pumpEventQueue();
      expect(server.sent('GET', '/items/notification_settings'), isNotEmpty);
    });
  });
}

/// Kho công tắc giữ lần [load] đầu tới khi [gate] hoàn tất.
class _GatedPrefsStore implements NotificationPrefsStore {
  _GatedPrefsStore(this._inner);

  final FakeNotificationPrefsStore _inner;
  final gate = Completer<void>();
  bool _first = true;

  @override
  Future<NotificationPrefs> load(String userId) async {
    if (_first) {
      _first = false;
      await gate.future;
    }
    return _inner.load(userId);
  }

  @override
  Future<void> save(String userId, NotificationPrefs prefs) =>
      _inner.save(userId, prefs);
}
