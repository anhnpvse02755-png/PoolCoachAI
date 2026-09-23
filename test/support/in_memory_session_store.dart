import 'package:poolcoachai/data/repositories/auth_repository.dart';

class InMemorySessionStore implements SessionStore {
  InMemorySessionStore([this.session]);

  StoredSession? session;

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<void> write(StoredSession s) async => session = s;

  @override
  Future<void> clear() async => session = null;
}
