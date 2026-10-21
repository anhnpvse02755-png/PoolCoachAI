// Điểm vào riêng cho kịch bản Chrome của Coach (tool/e2e/coach.mjs): app
// thật, nhưng đăng nhập sẵn một người chơi trên máy, không tạo tài khoản
// nào trên Directus. Build kèm API_URL trỏ về chỗ không có server, để mọi
// lượt đồng bộ báo "offline" và không dữ liệu nào rời máy:
//   flutter build web --release -t tool/e2e/coach_main.dart \
//     --dart-define=API_URL=http://127.0.0.1:9 -o build/web-coach-e2e
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/bootstrap.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/auth.dart';

/// Người chơi đã đăng nhập sẵn, không bao giờ gọi mạng.
class _LocalAuth implements AuthRepository {
  @override
  AuthState get current => const SignedIn(userId: 'e2e-coach', displayName: 'E2E');

  @override
  Stream<AuthState> watchSession() => const Stream.empty();

  @override
  Future<void> restore() async {}

  @override
  Future<String> accessToken() async => throw AuthFailure.network;

  @override
  Future<void> register({required String displayName, required String email, required String password}) async {}

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> resetPassword({required String token, required String password}) async {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(_LocalAuth())],
  );
  await loadSeed(container);
  startSync(container);
  runApp(UncontrolledProviderScope(container: container, child: const PoolCoachApp()));
}
