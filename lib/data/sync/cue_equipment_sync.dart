import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/category_compat.dart';
import 'package:poolcoachai/data/database/converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/skill_category.dart';

const cueEquipmentRemoteFields =
    'id,user_created,name,type,weight_grams,shaft_brand,tip_diameter_mm,'
    'tip_brand,tip_hardness,butt_brand,skill_categories,skill_categories_ext,last_tip_maintenance,tip_maintenance_due_date,'
    'updated_at,is_deleted';

Stream<List<CueEquipmentRow>> watchPendingCueEquipment(AppDatabase db) =>
    (db.select(
      db.cueEquipmentRows,
    )..where((row) => row.syncedAt.isNull())).watch();

class _CueEquipmentSyncStopped implements Exception {
  const _CueEquipmentSyncStopped();
}

class _CueEquipmentUserChanged implements Exception {
  const _CueEquipmentUserChanged();
}

class CueEquipmentSyncService {
  CueEquipmentSyncService({
    required this._db,
    required this._auth,
    required this._api,
    required this._now,
    this._retryEvery = const Duration(seconds: 30),
  });

  final AppDatabase _db;
  final AuthRepository _auth;
  final DirectusClient _api;
  final DateTime Function() _now;
  final Duration _retryEvery;

  bool _started = false;
  bool _disposed = false;
  bool _again = false;
  Future<SyncOutcome>? _running;
  Map<String, String> _pendingRevisions = {};
  final Set<String> _rejected = {};
  Timer? _timer;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<CueEquipmentRow>>? _pendingSubscription;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _authSubscription = _auth.watchSession().listen((state) {
      if (state is SignedIn) unawaited(syncNow());
    });
    _pendingSubscription = watchPendingCueEquipment(_db).listen((rows) {
      final current = {for (final row in rows) row.id: _revision(row)};
      final changed = current.entries.any(
        (entry) =>
            _pendingRevisions[entry.key] != entry.value &&
            _isCurrentOwner(entry.value),
      );
      _pendingRevisions = current;
      if (changed) unawaited(syncNow());
    });
    _timer = Timer.periodic(_retryEvery, (_) {
      if (_pendingRevisions.entries.any(
        (entry) =>
            _isCurrentOwner(entry.value) &&
            !_rejected.contains('${entry.key}:${entry.value}'),
      )) {
        unawaited(syncNow());
      }
    });
    unawaited(syncNow());
  }

  Future<SyncOutcome> syncNow() {
    if (_disposed) return Future.value(SyncOutcome.stopped);
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  Future<SyncOutcome> _loop() async {
    SyncOutcome outcome;
    do {
      _again = false;
      outcome = await _syncOnce();
    } while (_again && outcome == SyncOutcome.done && !_disposed);
    return outcome;
  }

  Future<SyncOutcome> _syncOnce() async {
    if (_disposed) return SyncOutcome.stopped;
    final state = _auth.current;
    if (state is! SignedIn) return SyncOutcome.signedOut;
    final userId = state.userId;
    try {
      final remoteItems = await _fetchRemote(userId);
      await _pushPending(userId, remoteItems);
      await _pullRemote(userId, remoteItems);
      return SyncOutcome.done;
    } on _CueEquipmentUserChanged {
      return SyncOutcome.signedOut;
    } on _CueEquipmentSyncStopped {
      return SyncOutcome.stopped;
    } on AuthFailure catch (failure) {
      return switch (failure) {
        AuthFailure.network => SyncOutcome.offline,
        AuthFailure.sessionExpired => SyncOutcome.signedOut,
        _ => SyncOutcome.failed,
      };
    } on DirectusUnreachable {
      return SyncOutcome.offline;
    } on Object {
      return SyncOutcome.failed;
    }
  }

  Future<List<Map<String, Object?>>> _fetchRemote(String userId) async {
    final token = await _tokenFor(userId);
    final result = await _api.get(
      '/items/cue_equipment',
      token: token,
      query: {'limit': '-1', 'fields': cueEquipmentRemoteFields},
    ) as List<Object?>;
    _checkAlive();
    _checkUser(userId);
    final items = result
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw const FormatException('Directus trả hồ sơ cơ sai định dạng');
          }
          if (_remoteOwner(item) != userId) {
            throw const FormatException(
              'Directus trả hồ sơ cơ không thuộc tài khoản hiện tại',
            );
          }
          return item;
        })
        .toList(growable: false);
    return items;
  }

  Future<void> _pushPending(
    String userId,
    List<Map<String, Object?>> remoteItems,
  ) async {
    final remoteById = {
      for (final item in remoteItems) _requiredString(item, 'id'): item,
    };
    final pending =
        await (_db.select(_db.cueEquipmentRows)
              ..where(
                (row) => row.userId.equals(userId) & row.syncedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.updatedAt)]))
            .get();

    for (final row in pending) {
      _checkAlive();
      _checkUser(userId);
      final key = '${row.id}:${_revision(row)}';
      if (_rejected.contains(key)) continue;
      final remote = remoteById[row.id];
      final localUpdatedAt = row.updatedAt;
      if (remote != null &&
          (localUpdatedAt == null ||
              !localUpdatedAt.isAfter(_parseDate(remote, 'updated_at')))) {
        continue;
      }

      final sentAt = localUpdatedAt ?? _now();
      final body = _toRemote(row, updatedAt: sentAt);
      try {
        final token = await _tokenFor(userId);
        if (remote == null) {
          try {
            await _api.post('/items/cue_equipment', token: token, body: body);
          } on DirectusError catch (error) {
            if (error.code != 'RECORD_NOT_UNIQUE') rethrow;
            await _api.patch(
              '/items/cue_equipment/${Uri.encodeComponent(row.id)}',
              token: await _tokenFor(userId),
              body: _withoutId(body),
            );
          }
        } else {
          await _api.patch(
            '/items/cue_equipment/${Uri.encodeComponent(row.id)}',
            token: token,
            body: _withoutId(body),
          );
        }
        _checkAlive();
        _checkUser(userId);
      } on DirectusError catch (error) {
        if (error.status >= 400 && error.status < 500 && error.status != 401) {
          _rejected.add(key);
          continue;
        }
        rethrow;
      }

      await _markSynced(row, sentAt);
    }
  }

  Future<void> _pullRemote(
    String userId,
    List<Map<String, Object?>> remoteItems,
  ) async {
    final receivedAt = _now();
    for (final item in remoteItems) {
      _checkAlive();
      _checkUser(userId);
      final remote = _fromRemote(item);
      await _db.transaction(() async {
        final local = await (_db.select(
          _db.cueEquipmentRows,
        )..where((row) => row.id.equals(remote.id))).getSingleOrNull();
        _checkAlive();
        _checkUser(userId);
        if (local != null && local.userId != userId) {
          throw const FormatException('ID cơ bị trùng giữa các tài khoản');
        }
        if (local?.updatedAt != null &&
            local!.updatedAt!.isAfter(remote.updatedAt!)) {
          return;
        }
        await _db
            .into(_db.cueEquipmentRows)
            .insertOnConflictUpdate(
              toCueEquipmentRow(
                remote,
                userId: userId,
                syncedAt: receivedAt,
                isDeleted: _remoteDeleted(item),
              ),
            );
        if (_remoteDeleted(item)) {
          await (_db.update(_db.timerSessionRows)..where(
                (row) =>
                    row.userId.equals(userId) & row.cueId.equals(remote.id),
              ))
              .write(const TimerSessionRowsCompanion(cueId: Value(null)));
        }
        _checkAlive();
        _checkUser(userId);
      });
    }
  }

  Future<void> _markSynced(CueEquipmentRow snapshot, DateTime sentAt) async {
    await _db.transaction(() async {
      final current = await (_db.select(
        _db.cueEquipmentRows,
      )..where((row) => row.id.equals(snapshot.id))).getSingleOrNull();
      if (current == null ||
          current.userId != snapshot.userId ||
          current.updatedAt != snapshot.updatedAt ||
          current.isDeleted != snapshot.isDeleted) {
        return;
      }
      await (_db.update(
        _db.cueEquipmentRows,
      )..where((row) => row.id.equals(snapshot.id))).write(
        CueEquipmentRowsCompanion(
          updatedAt: Value(snapshot.updatedAt ?? sentAt),
          syncedAt: Value(_now()),
        ),
      );
    });
  }

  ({List<String> legacy, List<String> ext}) _split(CueEquipmentRow row) =>
      splitCategoryNames((jsonDecode(row.skillCategories) as List).cast<String>());

  Map<String, Object?> _toRemote(
    CueEquipmentRow row, {
    required DateTime updatedAt,
  }) => {
    'id': row.id,
    'name': row.name,
    'type': row.type,
    'weight_grams': row.weightGrams,
    'shaft_brand': row.shaftBrand,
    // Tên trường giữ nguyên `tip_diameter_mm`; nghĩa là size ngọn.
    'tip_diameter_mm': row.shaftDiameterMm,
    'tip_brand': row.tipBrand,
    'tip_hardness': row.tipHardness,
    'butt_brand': row.buttBrand,
    // Nhóm nâng cao chỉ đi trong skill_categories_ext; bản đã phát hành ném
    // khi gặp tên lạ ở skill_categories.
    'skill_categories': _split(row).legacy,
    'skill_categories_ext': _split(row).ext,
    'last_tip_maintenance': _formatDateOnly(row.lastTipMaintenance),
    'tip_maintenance_due_date': _formatDateOnly(row.tipMaintenanceDueDate),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'is_deleted': row.isDeleted,
  };

  Map<String, Object?> _withoutId(Map<String, Object?> body) =>
      Map<String, Object?>.of(body)..remove('id');

  CueEquipment _fromRemote(Map<String, Object?> item) {
    final type = CueType.values.firstWhere(
      (value) => value.name == _requiredString(item, 'type'),
      orElse: () =>
          throw const FormatException('Loại cơ từ server không hợp lệ'),
    );
    final hardnessName = item['tip_hardness'] as String?;
    final hardness = hardnessName == null
        ? null
        : TipHardness.values.firstWhere(
            (value) => value.name == hardnessName,
            orElse: () => throw const FormatException(
              'Độ cứng đầu cơ từ server không hợp lệ',
            ),
          );
    final categories = item['skill_categories'];
    if (categories is! List<Object?> ||
        categories.any((category) => category is! String)) {
      throw const FormatException('Nhóm kỹ năng từ server không hợp lệ');
    }
    // Trường cũ vẫn parse nghiêm: tên lạ ở đây là dữ liệu hỏng, không phải
    // nhóm của bản sau (nhóm của bản sau chỉ đi trong skill_categories_ext).
    final legacyNames = [
      for (final category in categories)
        SkillCategory.values
            .firstWhere(
              (value) => value.name == category! as String,
              orElse: () => throw const FormatException(
                'Nhóm kỹ năng từ server không hợp lệ',
              ),
            )
            .name,
    ];
    final skills = joinCategoryNames(
      legacyNames,
      item['skill_categories_ext'],
    ).map(SkillCategory.values.byName).toList(growable: false);
    final weight = item['weight_grams'];
    final diameter = item['tip_diameter_mm'];
    if (weight != null && (weight is! int || weight <= 0)) {
      throw const FormatException('Trọng lượng cơ từ server không hợp lệ');
    }
    if (diameter != null &&
        (diameter is! num || !diameter.isFinite || diameter <= 0)) {
      throw const FormatException('Size ngọn từ server không hợp lệ');
    }
    final name = _requiredString(item, 'name');
    if (name.trim().isEmpty) {
      throw const FormatException('Tên cơ từ server không hợp lệ');
    }
    final cue = CueEquipment(
      id: _requiredString(item, 'id'),
      name: name,
      type: type,
      weightGrams: (weight as num?)?.toInt(),
      shaftBrand: _nullableText(item, 'shaft_brand'),
      shaftDiameterMm: (diameter as num?)?.toDouble(),
      tipBrand: _nullableText(item, 'tip_brand'),
      tipHardness: hardness,
      buttBrand: _nullableText(item, 'butt_brand'),
      skillCategories: skills,
      lastTipMaintenance: _nullableDate(item, 'last_tip_maintenance'),
      tipMaintenanceDueDate: _nullableDate(item, 'tip_maintenance_due_date'),
      updatedAt: _parseDate(item, 'updated_at'),
    );
    if (!isMaintenanceDueDateValid(
      lastMaintenance: cue.lastTipMaintenance,
      dueDate: cue.tipMaintenanceDueDate,
    )) {
      throw const FormatException('Ngày bảo dưỡng cơ từ server không hợp lệ');
    }
    return cue;
  }

  String _remoteOwner(Map<String, Object?> item) {
    final owner = item['user_created'];
    if (owner is String) return owner;
    if (owner is Map<String, Object?> && owner['id'] is String) {
      return owner['id']! as String;
    }
    throw const FormatException('Chủ hồ sơ cơ từ server không hợp lệ');
  }

  bool _remoteDeleted(Map<String, Object?> item) {
    final value = item['is_deleted'];
    if (value is bool) return value;
    throw const FormatException('Trạng thái xóa cơ từ server không hợp lệ');
  }

  String _requiredString(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('Trường $key từ server không hợp lệ');
  }

  String? _nullableText(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException('Trường $key từ server không hợp lệ');
  }

  DateTime _parseDate(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value is String) return DateTime.parse(value).toUtc();
    throw FormatException('Ngày $key từ server không hợp lệ');
  }

  DateTime? _nullableDate(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value == null) return null;
    if (value is String) {
      final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
      if (dateOnly != null) {
        final year = int.parse(dateOnly[1]!);
        final month = int.parse(dateOnly[2]!);
        final day = int.parse(dateOnly[3]!);
        final date = DateTime(year, month, day);
        if (date.year != year || date.month != month || date.day != day) {
          throw FormatException('Ngày $key từ server không hợp lệ');
        }
        return date;
      }
      return DateTime.parse(value).toLocal();
    }
    throw FormatException('Ngày $key từ server không hợp lệ');
  }

  String? _formatDateOnly(DateTime? value) => value == null
      ? null
      : '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';

  String _revision(CueEquipmentRow row) =>
      '${row.userId}:${row.updatedAt?.toIso8601String() ?? "unversioned"}:${row.isDeleted}';

  bool _isCurrentOwner(String revision) {
    final userId = switch (_auth.current) {
      SignedIn(:final userId) => userId,
      SignedOut() => null,
    };
    return userId != null && revision.startsWith('$userId:');
  }

  bool _stillSignedInAs(String userId) => switch (_auth.current) {
    SignedIn(userId: final id) => id == userId,
    SignedOut() => false,
  };

  Future<String> _tokenFor(String userId) async {
    final token = await _auth.accessToken();
    _checkUser(userId);
    return token;
  }

  void _checkUser(String userId) {
    if (!_stillSignedInAs(userId)) throw const _CueEquipmentUserChanged();
  }

  void _checkAlive() {
    if (_disposed) throw const _CueEquipmentSyncStopped();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _authSubscription?.cancel();
    _pendingSubscription?.cancel();
  }
}
