import 'dart:async';

import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/auth.dart';

/// AuthRepository giả cho widget test và test đồng bộ.
///
/// [nextFailure] làm lời gọi kế tiếp ném lỗi đó. [hold] giữ lời gọi
/// treo lại để test bấm nút hai lần.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository([AuthState initial = const SignedOut()]) : _state = initial;

  FakeAuthRepository.signedIn({String userId = 'u1', String displayName = 'An'})
      : this(SignedIn(userId: userId, displayName: displayName));

  AuthState _state;
  final _changes = StreamController<AuthState>.broadcast();
  final calls = <String>[];
  AuthFailure? nextFailure;
  Completer<void>? hold;

  /// Đặt khác null thì accessToken() ném lỗi này.
  AuthFailure? tokenFailure;

  void emit(AuthState state) {
    _state = state;
    _changes.add(state);
  }

  Future<void> _step(String call) async {
    calls.add(call);
    await hold?.future;
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
  }

  @override
  AuthState get current => _state;

  @override
  Stream<AuthState> watchSession() => _changes.stream;

  @override
  Future<void> restore() async => calls.add('restore');

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    await _step('register:$email');
    emit(SignedIn(userId: 'u1', displayName: displayName));
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _step('signIn:$email');
    emit(const SignedIn(userId: 'u1', displayName: 'An'));
  }

  @override
  Future<void> signOut() async {
    await _step('signOut');
    emit(const SignedOut());
  }

  @override
  Future<void> requestPasswordReset(String email) => _step('request:$email');

  @override
  Future<void> resetPassword({required String token, required String password}) =>
      _step('reset:$token');

  @override
  Future<String> accessToken() async {
    final failure = tokenFailure;
    if (failure != null) throw failure;
    return switch (_state) {
      SignedIn(:final userId) => 'access-$userId',
      SignedOut() => throw AuthFailure.sessionExpired,
    };
  }
}
