import 'package:poolcoachai/domain/pool_match.dart';

abstract interface class MatchRepository {
  Stream<List<PoolMatch>> watchAll();
  Future<void> start(PoolMatch match);
  Future<void> recordRack(String matchId, RackWinner winner);
  Future<void> undoLastRack(String matchId);
  Future<void> recordShot(String matchId, MatchShot shot);
  Future<void> undoLastShot(String matchId);
}

class SignedOutMatchRepository implements MatchRepository {
  const SignedOutMatchRepository();

  @override
  Stream<List<PoolMatch>> watchAll() => Stream.value(const []);

  @override
  Future<void> start(PoolMatch match) =>
      Future.error(StateError('Chưa đăng nhập thì không lưu trận đấu được'));

  @override
  Future<void> recordRack(String matchId, RackWinner winner) => Future.error(
    StateError('Chưa đăng nhập thì không ghi kết quả trận đấu được'),
  );

  @override
  Future<void> undoLastRack(String matchId) =>
      Future.error(StateError('Chưa đăng nhập thì không sửa trận đấu được'));

  @override
  Future<void> recordShot(String matchId, MatchShot shot) =>
      Future.error(StateError('Chưa đăng nhập thì không ghi cú đánh được'));

  @override
  Future<void> undoLastShot(String matchId) =>
      Future.error(StateError('Chưa đăng nhập thì không sửa cú đánh được'));
}
