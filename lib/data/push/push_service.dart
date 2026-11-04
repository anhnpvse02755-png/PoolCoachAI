import 'dart:async';

import 'package:poolcoachai/data/remote/codecs/remote_fields.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/remote/notify_client.dart';
import 'package:poolcoachai/data/push/push_platform.dart';
import 'package:poolcoachai/data/push/push_registration_store.dart';
import 'package:poolcoachai/data/push/push_types.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/notification_log.dart';
import 'package:poolcoachai/domain/notifications/push_state.dart';
import 'package:poolcoachai/domain/notifications/seed_fingerprint.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';

class PushService {
  PushService({
    required AuthRepository auth,
    required NotifyClient notify,
    required DirectusClient api,
    required PushPlatform platform,
    required PushRegistrationStore store,
    required DateTime Function() now,
    required String vapidPublicKey,
    required String? Function() permission,
    this.refreshEvery = const Duration(minutes: 30),
    this.resolveTimeout = const Duration(seconds: 10),
    this.unregisterTimeout = const Duration(seconds: 5),
  }) : _auth = auth,
       _platform = platform,
       _vapidPublicKey = vapidPublicKey,
       _state = !platform.isSupported || vapidPublicKey.isEmpty
           ? const PushUnavailable()
           : auth.current is SignedOut
           ? const PushLocal()
           : null {
    _notify = notify;
    _api = api;
    _store = store;
    _now = now;
    _permission = permission;
  }

  final AuthRepository _auth;
  late final NotifyClient _notify;
  late final DirectusClient _api;
  final PushPlatform _platform;
  late final PushRegistrationStore _store;
  late final DateTime Function() _now;
  final String _vapidPublicKey;
  late final String? Function() _permission;
  final Duration refreshEvery;
  final Duration resolveTimeout;
  final Duration unregisterTimeout;

  final _stateChanges = StreamController<PushState>.broadcast(sync: true);
  final _delivered =
      StreamController<(String, List<NotificationLogEntry>)>.broadcast(
        sync: true,
      );
  final _deviceIds = <String, String>{};
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<PushShown>? _shownSubscription;
  Timer? _timer;
  PushState? _state;
  String? _userId;
  String? _fingerprint;
  Completer<void>? _catalogReady;
  final _pulls = <String, Future<void>>{};
  int _generation = 0;
  bool _started = false;
  bool _disposed = false;

  Stream<PushState> get states => Stream.multi((controller) {
    final subscription = _stateChanges.stream.listen(controller.add);
    final state = _state;
    if (state != null) controller.add(state);
    controller.onCancel = subscription.cancel;
  });

  Stream<(String, List<NotificationLogEntry>)> get delivered =>
      _delivered.stream;

  void setCatalog(List<Drill> drills, List<KnowledgeArticle> knowledge) {
    _fingerprint = seedFingerprint(drills: drills, knowledge: knowledge);
    _catalogReady?.complete();
    _catalogReady = null;
  }

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _userId = _signedInUserId;
    _authSubscription = _auth.watchSession().listen((state) {
      final next = switch (state) {
        SignedIn(:final userId) => userId,
        SignedOut() => null,
      };
      if (next == _userId) return;
      _generation++;
      _userId = next;
      if (next == null) {
        _emit(
          _platform.isSupported && _vapidPublicKey.isNotEmpty
              ? const PushLocal()
              : const PushUnavailable(),
        );
      } else {
        _emitIfKnownUnavailable();
        unawaited(refresh());
      }
    });
    _shownSubscription = _platform.shown.listen(_onShown);
    _timer = Timer.periodic(refreshEvery, (_) => unawaited(refresh()));
    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final userId = _signedInUserId;
    if (_userId != userId) {
      _generation++;
      _userId = userId;
    }

    final generation = _generation;
    if (!_platform.isSupported || _vapidPublicKey.isEmpty) {
      _emit(const PushUnavailable());
      return;
    }
    if (userId == null) {
      _emit(const PushLocal());
      return;
    }
    _userId = userId;
    final operation = _resolve(userId, generation);
    await operation.timeout(
      resolveTimeout,
      onTimeout: () {
        if (_isCurrent(userId, generation)) {
          if (_state == null) {
            _emit(const PushLocal());
          } else {
            _emitActiveStored(userId);
          }
        }
      },
    );
  }

  void refreshAfterPermissionChange() {
    unawaited(refresh());
  }

  Future<void> _resolve(String userId, int generation) async {
    try {
      final stored = await _store.load(userId);
      if (!_isCurrent(userId, generation)) return;
      if (stored != null && stored.activeAt(_now())) {
        _deviceIds[userId] = stored.deviceId;
        _emit(PushServer(stored));
      }
      if (_permission() != 'granted') {
        _emit(const PushLocal());
        return;
      }
      final config = await _notify.config();
      if (!_isCurrent(userId, generation)) return;
      if (!config.enabled || config.publicKey != _vapidPublicKey) {
        _emit(const PushLocal());
        return;
      }
      final subscription = await _platform.subscribe(_vapidPublicKey);
      if (!_isCurrent(userId, generation)) return;
      if (_fingerprint == null) {
        final ready = _catalogReady ??= Completer<void>();
        await ready.future.timeout(resolveTimeout, onTimeout: () {});
      }
      if (!_isCurrent(userId, generation)) return;
      final token = await _auth.accessToken();
      if (!_isCurrent(userId, generation)) return;
      final registration = await _notify.register(
        token: token,
        subscription: subscription,
        timezone: _platform.timeZone ?? 'UTC',
        seedFingerprint: _fingerprint,
        vapidPublicKey: _vapidPublicKey,
      );
      if (!_isCurrent(userId, generation)) return;
      _deviceIds[userId] = registration.deviceId;
      final leaseUntil = registration.leaseUntil;
      if (!registration.enabled || leaseUntil == null) {
        await _store.forget(userId);
        if (!_isCurrent(userId, generation)) return;
        _emit(const PushLocal());
      } else {
        final lease = PushLease(
          userId: userId,
          deviceId: registration.deviceId,
          serverKinds: registration.serverKinds,
          until: _now().add(leaseUntil.difference(registration.serverNow)),
        );
        if (lease.serverKinds.isEmpty || !lease.activeAt(_now())) {
          await _store.forget(userId);
          if (!_isCurrent(userId, generation)) return;
          _emit(const PushLocal());
        } else {
          await _store.save(lease);
          if (!_isCurrent(userId, generation)) return;
          _emit(PushServer(lease));
        }
      }
      await pullDeliveries();
    } on NotifyError {
      _fallback(userId, generation);
    } on NotifyUnreachable {
      _fallback(userId, generation);
    } on DirectusError {
      _fallback(userId, generation);
    } on DirectusUnreachable {
      _fallback(userId, generation);
    } on PushPlatformException {
      _fallback(userId, generation);
    } on AuthFailure {
      _fallback(userId, generation);
    } on TimeoutException {
      _fallback(userId, generation);
    } on FormatException {
      _fallback(userId, generation);
    } on TypeError {
      _fallback(userId, generation);
    }
  }

  Future<void> pullDeliveries() {
    final userId = _signedInUserId;
    if (userId == null) return Future.value();
    final current = _pulls[userId];
    if (current != null) return current;
    late final Future<void> request;
    request = _pullFor(userId).whenComplete(() => _pulls.remove(userId));
    _pulls[userId] = request;
    return request;
  }

  Future<void> _pullFor(String userId) async {
    try {
      var deviceId = _deviceIds[userId];
      deviceId ??= (await _store.load(userId))?.deviceId;
      if (deviceId == null || _signedInUserId != userId) return;
      _deviceIds[userId] = deviceId;
      final token = await _auth.accessToken();
      if (_signedInUserId != userId) return;
      final response = await _api.get(
        '/items/push_deliveries',
        token: token,
        query: {
          'filter[device][_eq]': deviceId,
          'filter[shown_at][_nnull]': 'true',
          'filter[shown_at][_gte]': _now()
              .subtract(const Duration(days: 30))
              .toUtc()
              .toIso8601String(),
          'fields': pushDeliveryRemoteFields,
          'limit': '-1',
        },
      );
      if (_signedInUserId != userId) return;
      if (response is! List) return;
      final entries = <NotificationLogEntry>[];
      for (final row in response) {
        if (row is! Map) continue;
        final kind = _kind(row['kind']);
        final id = row['notification_id'];
        final key = row['key'];
        final title = row['title'];
        final body = row['body'];
        final shown = row['shown_at'];
        final at = shown is String ? DateTime.tryParse(shown) : null;
        if (kind == null ||
            id is! num ||
            !id.isFinite ||
            id != id.truncate() ||
            key is! String ||
            title is! String ||
            body is! String ||
            at == null) {
          continue;
        }
        entries.add(
          NotificationLogEntry(
            id: id.toInt(),
            kind: kind,
            key: key,
            at: at.toLocal(),
            title: title,
            body: body,
          ),
        );
      }
      if (entries.isNotEmpty) _delivered.add((userId, entries));
    } on DirectusError {
      // Delivery sync can retry on the next refresh or shown event.
    } on DirectusUnreachable {
      // Delivery sync can retry on the next refresh or shown event.
    } on AuthFailure {
      // Delivery sync can retry on the next refresh or shown event.
    } on TimeoutException {
      // Delivery sync can retry on the next refresh or shown event.
    } on FormatException {
      // Malformed response bodies can be retried on the next sync.
    }
  }

  void _onShown(PushShown shown) {
    final userId = _signedInUserId;
    if (userId == null || _userId != userId || _disposed) return;
    _delivered.add((
      userId,
      [
        NotificationLogEntry(
          id: shown.notificationId,
          kind: shown.kind,
          key: shown.key,
          at: shown.shownAt.toLocal(),
          title: shown.title,
          body: shown.body,
        ),
      ],
    ));
    unawaited(pullDeliveries());
  }

  Future<void> unregister(String userId) async {
    final current = _signedInUserId;
    var deviceId = _deviceIds[userId];
    try {
      deviceId ??= (await _store.load(userId))?.deviceId;
      if (current == userId && deviceId != null) {
        final token = await _auth.accessToken().timeout(unregisterTimeout);
        if (_signedInUserId == userId) {
          await _notify
              .unregister(token: token, deviceId: deviceId)
              .timeout(unregisterTimeout);
        }
      }
    } finally {
      try {
        if (current == userId && _signedInUserId == userId) {
          await _platform.unsubscribe();
        }
      } finally {
        _deviceIds.remove(userId);
        await _store.forget(userId);
        if (_userId == userId) _emit(const PushLocal());
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    unawaited(_authSubscription?.cancel());
    unawaited(_shownSubscription?.cancel());
    unawaited(_stateChanges.close());
    unawaited(_delivered.close());
  }

  void _fallback(String userId, int generation) {
    if (!_isCurrent(userId, generation)) return;
    final state = _state;
    if (state is PushServer &&
        state.lease.userId == userId &&
        state.lease.activeAt(_now())) {
      return;
    }
    _emitActiveStored(userId);
  }

  void _emitActiveStored(String userId) {
    unawaited(
      _store
          .load(userId)
          .then((lease) {
            if (_signedInUserId != userId || _disposed) return;
            if (lease != null && lease.activeAt(_now())) {
              _deviceIds[userId] = lease.deviceId;
              _emit(PushServer(lease));
            } else {
              _emit(const PushLocal());
            }
          })
          .catchError((Object _) {
            if (_signedInUserId == userId && !_disposed) {
              _emit(const PushLocal());
            }
          }),
    );
  }

  void _emitIfKnownUnavailable() {
    if (!_platform.isSupported || _vapidPublicKey.isEmpty) {
      _emit(const PushUnavailable());
    }
  }

  void _emit(PushState state) {
    if (_disposed) return;
    _state = state;
    _stateChanges.add(state);
  }

  bool _isCurrent(String userId, int generation) =>
      !_disposed &&
      _generation == generation &&
      _userId == userId &&
      _signedInUserId == userId;

  String? get _signedInUserId => switch (_auth.current) {
    SignedIn(:final userId) => userId,
    SignedOut() => null,
  };

  static NotificationKind? _kind(Object? value) {
    if (value is! String) return null;
    for (final kind in NotificationKind.values) {
      if (kind.name == value) return kind;
    }
    return null;
  }
}
