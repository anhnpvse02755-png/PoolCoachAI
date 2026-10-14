import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/rank_merge.dart';
import 'package:poolcoachai/domain/rank.dart';

/// Quy tắc gộp của spec mục 6.2: bản mới nhất thắng, trừ bản đã kiểm
/// chứng không bao giờ bị bản ước lượng/tự khai ghi đè.
void main() {
  final older = DateTime(2026, 10, 1);
  final newer = DateTime(2026, 10, 9);

  PlayerRank r(Rank? rank, RankSource? source, DateTime at) => PlayerRank(
        rank: rank,
        source: source,
        buScore: source == RankSource.verified ? 120 : null,
        testId: source == RankSource.verified ? 't-$rank' : null,
        onboardingState: rank == null ? OnboardingState.skipped : OnboardingState.done,
        updatedAt: at,
      );

  test('một bên trống thì lấy bên kia', () {
    final x = r(Rank.g, RankSource.estimated, older);
    expect(mergeRank(null, null), isNull);
    expect(identical(mergeRank(x, null), x), isTrue);
    expect(identical(mergeRank(null, x), x), isTrue);
  });

  test('máy khác tự khai mới hơn không ghi đè hạng đã kiểm chứng', () {
    final verified = r(Rank.e, RankSource.verified, older);
    final declared = r(Rank.pro, RankSource.selfDeclared, newer);
    expect(identical(mergeRank(declared, verified), verified), isTrue);
    expect(identical(mergeRank(verified, declared), verified), isTrue);
  });

  test('ước lượng mới hơn cũng không ghi đè hạng đã kiểm chứng', () {
    final verified = r(Rank.e, RankSource.verified, older);
    final estimated = r(Rank.c, RankSource.estimated, newer);
    expect(identical(mergeRank(estimated, verified), verified), isTrue);
  });

  test('hai bản cùng chưa kiểm chứng: mới hơn thắng', () {
    final a = r(Rank.g, RankSource.estimated, older);
    final b = r(Rank.f, RankSource.selfDeclared, newer);
    expect(identical(mergeRank(a, b), b), isTrue);
    expect(identical(mergeRank(b, a), b), isTrue);
  });

  test('hai bản đã kiểm chứng khác hạng: hạng cao hơn thắng, dù cũ hơn (D4)', () {
    final high = r(Rank.b, RankSource.verified, older);
    final low = r(Rank.d, RankSource.verified, newer);
    expect(identical(mergeRank(high, low), high), isTrue);
    expect(identical(mergeRank(low, high), high), isTrue);
  });

  test('hai bản đã kiểm chứng cùng hạng: mới hơn thắng (D4)', () {
    final a = r(Rank.d, RankSource.verified, older);
    final b = PlayerRank(
      rank: Rank.d,
      source: RankSource.verified,
      buScore: 130,
      testId: 't-moi',
      onboardingState: OnboardingState.done,
      updatedAt: newer,
    );
    expect(identical(mergeRank(a, b), b), isTrue);
    expect(identical(mergeRank(b, a), b), isTrue);
  });

  group('lần kiểm chứng thấp hơn bị thua thành cảnh báo (D4, luật 4)', () {
    PlayerRank verified(Rank rank, String testId, DateTime at) => PlayerRank(
          rank: rank,
          source: RankSource.verified,
          buScore: 120,
          testId: testId,
          onboardingState: OnboardingState.done,
          updatedAt: at,
        );

    test('lần thấp hơn mới hơn: giữ hạng cao, đặt cảnh báo trỏ tới lần thấp', () {
      final high = verified(Rank.b, 'tB', older);
      final low = verified(Rank.d, 'tD', newer);
      final w = warnOfLowerTest(high, low);
      expect(w.rank, Rank.b);
      expect(w.testId, 'tB');
      expect(w.buScore, 120);
      expect(w.warningRank, Rank.d);
      expect(w.warningTestId, 'tD');
      expect(w.updatedAt, newer, reason: 'bản gộp mới nhất, để lần gộp sau giữ nó');
    });

    test('lần thấp hơn cũ hơn lần kiểm chứng thắng: không cảnh báo (đã bị lần sau xoá)', () {
      final high = verified(Rank.b, 'tB', newer);
      final low = verified(Rank.d, 'tD', older);
      expect(identical(warnOfLowerTest(high, low), high), isTrue);
    });

    test('bên thua không phải bản kiểm chứng thấp hơn: giữ nguyên bên thắng', () {
      final high = verified(Rank.b, 'tB', older);
      expect(identical(warnOfLowerTest(high, null), high), isTrue);
      expect(identical(warnOfLowerTest(high, r(Rank.c, RankSource.selfDeclared, newer)), high),
          isTrue);
      expect(identical(warnOfLowerTest(high, verified(Rank.b, 'tB2', newer)), high), isTrue);
      final unverified = r(Rank.a, RankSource.selfDeclared, older);
      expect(identical(warnOfLowerTest(unverified, verified(Rank.d, 'tD', newer)), unverified),
          isTrue, reason: 'bản chưa kiểm chứng không bao giờ thắng bản kiểm chứng');
    });

    test('đã cảnh báo đúng lần đó thì không đổi', () {
      final low = verified(Rank.d, 'tD', newer);
      final warned = PlayerRank(
        rank: Rank.b,
        source: RankSource.verified,
        buScore: 120,
        testId: 'tB',
        warningRank: Rank.d,
        warningTestId: 'tD',
        onboardingState: OnboardingState.done,
        updatedAt: newer,
      );
      expect(identical(warnOfLowerTest(warned, low), warned), isTrue);
    });
  });

  test('bản chưa có hạng (Để sau) không xoá hạng đã có, dù mới hơn (D16)', () {
    final skipped = r(null, null, newer);
    final estimated = r(Rank.h, RankSource.estimated, older);
    expect(identical(mergeRank(skipped, estimated), estimated), isTrue);
    expect(identical(mergeRank(estimated, skipped), estimated), isTrue);
  });

  test('hoà giờ: giữ bản trên máy', () {
    final local = r(Rank.g, RankSource.estimated, older);
    final remote = r(Rank.f, RankSource.estimated, older);
    expect(identical(mergeRank(local, remote), local), isTrue);
  });
}
