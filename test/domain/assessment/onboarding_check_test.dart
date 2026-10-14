import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/onboarding_check.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';

/// Spec mục 7.1 và 8: chỉ ép onboarding khi chắc chắn tài khoản chưa có dòng
/// hạng nào — trên máy, hoặc máy chủ đã trả lời là không có.
void main() {
  final at = DateTime(2026, 10, 14);
  final skipped = PlayerRank(onboardingState: OnboardingState.skipped, updatedAt: at);
  final notStarted = PlayerRank(onboardingState: OnboardingState.notStarted, updatedAt: at);

  OnboardingCheck d(PlayerRank? local, RankFetch fetch, {bool loaded = true}) =>
      decideOnboarding(rankLoaded: loaded, local: local, fetch: fetch);

  test('máy đã có dòng hạng: theo trạng thái của dòng đó', () {
    expect(d(skipped, RankFetch.pending), OnboardingCheck.notRequired);
    expect(d(notStarted, RankFetch.pending), OnboardingCheck.required);
  });

  test('máy chưa có gì, máy chủ trả lời không có: vào onboarding', () {
    expect(d(null, RankFetch.foundNone), OnboardingCheck.required);
  });

  test('máy chưa có gì, chưa hỏi xong máy chủ: chưa quyết, không chuyển', () {
    expect(d(null, RankFetch.pending), OnboardingCheck.notRequired);
  });

  test('máy mới mất mạng: không ép onboarding', () {
    expect(d(null, RankFetch.failed), OnboardingCheck.notRequired);
  });

  test('máy chủ có dòng hạng mà Drift chưa kịp bắn lại: không chuyển', () {
    expect(d(null, RankFetch.found), OnboardingCheck.notRequired);
  });

  test('Drift chưa trả lời: không chuyển', () {
    expect(d(null, RankFetch.foundNone, loaded: false), OnboardingCheck.notRequired);
  });
}
