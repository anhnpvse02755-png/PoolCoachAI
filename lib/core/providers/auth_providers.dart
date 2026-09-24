import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:poolcoachai/core/auth/auth_gate.dart';
import 'package:poolcoachai/core/config.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/data/remote/directus_auth_repository.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/data/repositories/drift_session_store.dart';
import 'package:poolcoachai/data/sync/sync_service.dart';
import 'package:poolcoachai/domain/auth.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final directusClientProvider = Provider<DirectusClient>((ref) {
  return DirectusClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Uri.parse(apiBaseUrl),
  );
});

/// Một instance cho cả app: nó giữ access token và trạng thái đăng nhập.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return DirectusAuthRepository(
    api: ref.watch(directusClientProvider),
    sessions: DriftSessionStore(ref.watch(appDatabaseProvider)),
    resetUrl: resetPasswordUrl(),
    now: ref.watch(nowProvider),
  );
});

/// Trạng thái đăng nhập, đọc đồng bộ — không có pha "đang tải".
final authStateProvider =
    NotifierProvider<AuthStateNotifier, AuthState>(AuthStateNotifier.new);

class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repo = ref.watch(authRepositoryProvider);
    final sub = repo.watchSession().listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return repo.current;
  }
}

/// Người đang đăng nhập; null khi chưa đăng nhập.
final currentUserIdProvider = Provider<String?>((ref) {
  return switch (ref.watch(authStateProvider)) {
    SignedIn(:final userId) => userId,
    SignedOut() => null,
  };
});

final authGateProvider = Provider<AuthGate>((ref) {
  final gate = AuthGate(ref.watch(authRepositoryProvider));
  ref.onDispose(gate.dispose);
  return gate;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    db: ref.watch(appDatabaseProvider),
    auth: ref.watch(authRepositoryProvider),
    api: ref.watch(directusClientProvider),
    now: ref.watch(nowProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
