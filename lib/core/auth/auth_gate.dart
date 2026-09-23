import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/auth.dart';

/// Cầu nối từ trạng thái đăng nhập sang `refreshListenable` của router.
///
/// Đăng nhập, đăng xuất hay phiên hết hạn đều làm router chạy lại
/// redirect, nên không màn nào phải tự điều hướng sau khi xong việc.
class AuthGate extends ChangeNotifier {
  AuthGate(AuthRepository repo) : _state = repo.current {
    _sub = repo.watchSession().listen((state) {
      _state = state;
      notifyListeners();
    });
  }

  /// Cổng đứng yên — cho test chỉ cần một trạng thái cố định.
  AuthGate.fixed(AuthState state) : _state = state;

  AuthState _state;
  StreamSubscription<AuthState>? _sub;

  AuthState get state => _state;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
