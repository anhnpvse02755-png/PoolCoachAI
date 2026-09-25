import 'dart:async';

import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/auth.dart';

/// Xác thực qua Directus: refresh token trên máy, access token trong bộ nhớ.
class DirectusAuthRepository implements AuthRepository {
  DirectusAuthRepository({
    required this._api,
    required this._sessions,
    required this._resetUrl,
    required this._now,
  });

  final DirectusClient _api;
  final SessionStore _sessions;
  final Uri _resetUrl;
  final DateTime Function() _now;

  static const _minPasswordLength = 8;
  static const _refreshMargin = Duration(minutes: 1);

  final _changes = StreamController<AuthState>.broadcast();
  AuthState _state = const SignedOut();
  String? _accessToken;
  DateTime? _accessExpiresAt;
  Future<String>? _refreshing;
  int _gen = 0; // session generation: incremented on every sign-in/sign-out/_expire
  // signIn đã đổi thế hệ và đang chờ ghi phiên người mới, trạng thái vẫn
  // là người cũ. Ai xin token lúc này đang làm việc cho người cũ.
  bool _committingSignIn = false;

  @override
  AuthState get current => _state;

  @override
  Stream<AuthState> watchSession() => _changes.stream;

  void _emit(AuthState state) {
    if (state == _state) return;
    _state = state;
    _changes.add(state);
  }

  void _bumpGen() => _gen++;

  static String _normalize(String email) => email.trim().toLowerCase();

  @override
  Future<void> restore() async {
    final saved = await _sessions.read();
    if (saved != null) {
      _emit(SignedIn(userId: saved.userId, displayName: saved.displayName));
    }
  }

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    if (password.length < _minPasswordLength) throw AuthFailure.weakPassword;
    final normalized = _normalize(email);
    try {
      await _api.post('/users/register', body: {
        'email': normalized,
        'password': password,
        'first_name': displayName.trim(),
      });
    } on DirectusUnreachable {
      throw AuthFailure.network;
    } on DirectusError catch (e) {
      // Email đã có chủ — có thể chính là người này, từ lần đăng ký trước
      // hỏng mạng sau khi tài khoản đã tạo. Đăng nhập thử bên dưới quyết định.
      if (e.code != 'RECORD_NOT_UNIQUE') {
        throw e.code == 'FAILED_VALIDATION'
            ? AuthFailure.weakPassword
            : AuthFailure.unknown;
      }
    }
    try {
      await signIn(email: normalized, password: password);
    } on AuthFailure catch (f) {
      // Directus có thể không báo email trùng khi đăng ký (chống dò
      // email). Đăng ký "thành công" mà đăng nhập hỏng nghĩa là email
      // đã có chủ với mật khẩu khác.
      throw f == AuthFailure.wrongCredentials ? AuthFailure.emailTaken : f;
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    // Phiên cũ (nếu có) hết hiệu lực ngay từ đây: một lượt làm mới của nó
    // về muộn thấy thế hệ đã đổi và bỏ kết quả, không đè token mới.
    _bumpGen();
    _refreshing = null;
    // Token của phiên cũ cũng hết hiệu lực luôn: không để ai còn cầm nó
    // trong lúc phiên đang đổi chủ.
    _accessToken = null;
    _accessExpiresAt = null;

    final Map<String, Object?> tokens;
    try {
      tokens = await _api.post('/auth/login', body: {
        'email': _normalize(email),
        'password': password,
        'mode': 'json',
      }) as Map<String, Object?>;
    } on DirectusUnreachable {
      throw AuthFailure.network;
    } on DirectusError catch (e) {
      throw e.status == 401 ? AuthFailure.wrongCredentials : AuthFailure.unknown;
    }

    // Chưa giữ token cho tới khi biết là của ai: /users/me hỏng thì lần
    // đăng nhập này coi như chưa từng có.
    final Map<String, Object?> me;
    try {
      me = await _api.get(
        '/users/me',
        token: tokens['access_token']! as String,
        query: {'fields': 'id,first_name'},
      ) as Map<String, Object?>;
    } on DirectusUnreachable {
      throw AuthFailure.network;
    } on DirectusError {
      throw AuthFailure.unknown;
    }

    final session = StoredSession(
      userId: me['id']! as String,
      displayName: (me['first_name'] as String?) ?? '',
      refreshToken: tokens['refresh_token']! as String,
    );
    // Lần nữa, ngay trước khi giữ token và chưa chờ gì: lượt làm mới bắt
    // đầu giữa chừng (lúc chờ /users/me, còn đọc phiên cũ) mà về trong lúc
    // ta chờ ghi phiên sẽ thấy thế hệ đã đổi, không đè token hay phiên mới.
    _bumpGen();
    // Token người mới chỉ vào tay cùng lúc với SignedIn(người mới), không
    // chờ gì giữa hai việc: trong lúc chờ ghi, trạng thái vẫn là người cũ,
    // và ai xin token lúc đó sẽ đẩy dữ liệu người cũ bằng token người mới.
    // Cũng không cho họ đi làm mới phiên người cũ: lần ghi của lượt đó sẽ
    // đè phiên người mới vừa ghi.
    final accessToken = tokens['access_token']! as String;
    final accessExpiresAt = _expiresAt(tokens);
    _committingSignIn = true;
    try {
      await _sessions.write(session);
    } finally {
      _committingSignIn = false;
    }
    _accessToken = accessToken;
    _accessExpiresAt = accessExpiresAt;
    _emit(SignedIn(userId: session.userId, displayName: session.displayName));
  }

  DateTime _expiresAt(Map<String, Object?> tokens) => _now().add(
        Duration(milliseconds: (tokens['expires']! as num).toInt()),
      );

  void _takeTokens(Map<String, Object?> tokens) {
    _accessToken = tokens['access_token']! as String;
    _accessExpiresAt = _expiresAt(tokens);
  }

  @override
  Future<String> accessToken() {
    if (_state is! SignedIn || _committingSignIn) {
      return Future.error(AuthFailure.sessionExpired);
    }
    final token = _accessToken;
    final expiresAt = _accessExpiresAt;
    if (token != null &&
        expiresAt != null &&
        expiresAt.difference(_now()) > _refreshMargin) {
      return Future.value(token);
    }
    return _refreshing ??= _genStableRefresh();
  }

  /// Like _refresh() but stable: the whenComplete cleanup only nulls
  /// _refreshing if that slot still holds this same future — not if a later
  /// call's refresh has already replaced it.
  Future<String> _genStableRefresh() {
    late final Future<String> f;
    f = _refresh().whenComplete(() {
      if (identical(_refreshing, f)) _refreshing = null;
    });
    _refreshing = f; // assign before return so identical() is true when wc fires
    return f;
  }

  /// Mỗi lượt làm mới thử tối đa ngần này refresh token khác nhau.
  static const _maxRefreshTokens = 3;

  Future<String> _refresh() async {
    // Lấy thế hệ trước lần chờ đầu tiên: mọi kết luận của lượt này (ghi
    // phiên, hay đăng xuất vì hết hạn) chỉ có hiệu lực nếu phiên chưa đổi.
    // Kiểm lại sau **mỗi** lần chờ — lượt cũ về muộn luôn là sessionExpired.
    final startGen = _gen;
    void stillCurrent() {
      if (_gen != startGen) throw AuthFailure.sessionExpired;
    }

    // Phiên trên máy dùng chung với mọi tab (Drift web là một DB). Phiên
    // của người khác nghĩa là tab khác đã đổi người: không được dùng token
    // của họ, cũng không được xoá phiên của họ.
    bool foreign(StoredSession s) {
      final who = _state;
      return who is! SignedIn || who.userId != s.userId;
    }

    final tried = <String>{};
    var saved = await _sessions.read();
    stillCurrent();
    while (true) {
      if (saved != null && foreign(saved)) {
        _dropForeign(ifGen: startGen);
        throw AuthFailure.sessionExpired;
      }
      if (saved == null) {
        // Máy hết phiên mà server chưa từ chối gì: tab khác đã đăng xuất.
        await _expire(ifGen: startGen, expired: false);
        throw AuthFailure.sessionExpired;
      }
      final used = saved.refreshToken;
      tried.add(used);

      final Map<String, Object?> tokens;
      try {
        tokens = await _api.post('/auth/refresh', body: {
          'refresh_token': used,
          'mode': 'json',
        }) as Map<String, Object?>;
      } on DirectusUnreachable {
        // Mất mạng không bao giờ là lý do đăng xuất.
        throw AuthFailure.network;
      } on DirectusError catch (e) {
        if (e.status != 401 && e.status != 403) throw AuthFailure.unknown;
        stillCurrent();
        // Một tab khác có thể vừa xoay token. Máy đang cầm token chưa thử
        // thì thử token đó; còn cầm đúng token vừa bị từ chối thì phiên chết.
        final latest = await _sessions.read();
        stillCurrent();
        if (latest != null && foreign(latest)) {
          _dropForeign(ifGen: startGen);
          throw AuthFailure.sessionExpired;
        }
        if (latest == null || latest.refreshToken == used) {
          await _expire(ifGen: startGen, expired: latest != null);
          throw AuthFailure.sessionExpired;
        }
        if (tried.contains(latest.refreshToken) ||
            tried.length >= _maxRefreshTokens) {
          // Các tab đang xoay token liên tục — để lần sau thử lại.
          throw AuthFailure.network;
        }
        saved = latest;
        continue;
      }

      final rotated = tokens['refresh_token']! as String;
      if (_gen != startGen) {
        // Server vừa xoay token cho một phiên đã bỏ: token mới này không ai
        // giữ, báo server bỏ luôn thay vì để nó sống 30 ngày.
        unawaited(_revoke(rotated));
        throw AuthFailure.sessionExpired;
      }
      _takeTokens(tokens);
      await _sessions.write(StoredSession(
        userId: saved.userId,
        displayName: saved.displayName,
        refreshToken: rotated,
      ));
      if (_gen != startGen) {
        unawaited(_revoke(rotated));
        throw AuthFailure.sessionExpired;
      }
      return _accessToken!;
    }
  }

  /// Tự động đăng xuất: chỉ bỏ phiên. **Không** động tới buổi tập nào —
  /// người chơi đăng nhập lại thì mọi thứ còn nguyên (spec mục 5.4).
  ///
  /// [ifGen] là thế hệ lượt refresh bắt đầu. Một lượt cũ về muộn — sau khi
  /// người chơi đã đăng xuất rồi đăng nhập lại — không được đá phiên mới.
  /// [expired] chỉ true khi server thật sự từ chối phiên: màn Đăng nhập
  /// dựa vào nó để nói "phiên hết hạn".
  Future<void> _expire({required int ifGen, required bool expired}) async {
    if (_gen != ifGen) return;
    _bumpGen();
    final mine = _gen;
    await _sessions.clear();
    if (_gen != mine) return;
    _accessToken = null;
    _accessExpiresAt = null;
    _emit(SignedOut(expired: expired));
  }

  /// Tự động đăng xuất vì tab khác đã đăng nhập người khác: như [_expire]
  /// (đổi thế hệ, bỏ token, [SignedOut] thường vì server chưa từ chối gì),
  /// nhưng **không** xoá phiên trên máy — đó là phiên hợp lệ của tab kia.
  /// Không động tới buổi tập nào (spec mục 5.4).
  void _dropForeign({required int ifGen}) {
    if (_gen != ifGen) return;
    _bumpGen();
    _accessToken = null;
    _accessExpiresAt = null;
    _emit(const SignedOut());
  }

  /// Đăng xuất trên máy **trước**, rồi mới báo server ở nền.
  ///
  /// Trạng thái phải thành [SignedOut] trước bất kỳ lần chờ mạng nào:
  /// một lượt kéo về đang chạy chỉ biết dừng khi thấy người dùng đổi,
  /// và nếu ta chờ `/auth/logout` (tới ~30 giây) trước, nó sẽ ghi lại
  /// đúng những buổi tập người chơi vừa bấm xoá.
  @override
  Future<void> signOut() async {
    final saved = await _sessions.read();
    _refreshing = null;
    _accessToken = null;
    _accessExpiresAt = null;
    _bumpGen();
    await _sessions.clear();
    _emit(const SignedOut());
    if (saved != null) unawaited(_revoke(saved.refreshToken));
  }

  /// Báo server bỏ refresh token. Hỏng thế nào cũng không sao: token
  /// tự hết hạn sau 30 ngày, và máy đã quên nó rồi.
  Future<void> _revoke(String refreshToken) async {
    try {
      await _api.post('/auth/logout', body: {
        'refresh_token': refreshToken,
        'mode': 'json',
      });
    } on Object {
      // Mất mạng, token đã chết sẵn, server lỗi — đều bỏ qua.
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _api.post('/auth/password/request', body: {
        'email': _normalize(email),
        'reset_url': _resetUrl.toString(),
      });
    } on DirectusUnreachable {
      throw AuthFailure.network;
    } on DirectusError {
      throw AuthFailure.unknown;
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    if (password.length < _minPasswordLength) throw AuthFailure.weakPassword;
    try {
      await _api.post('/auth/password/reset', body: {
        'token': token,
        'password': password,
      });
    } on DirectusUnreachable {
      throw AuthFailure.network;
    } on DirectusError catch (e) {
      throw switch (e.status) {
        401 || 403 => AuthFailure.resetLinkInvalid,
        400 when e.code == 'FAILED_VALIDATION' => AuthFailure.weakPassword,
        _ => AuthFailure.unknown,
      };
    }
  }
}
