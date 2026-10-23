import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/coach_chat_providers.dart';
import 'package:poolcoachai/domain/pool_match.dart';

import '../../support/coach_chat_fixtures.dart';
import '../../support/test_data.dart';

void main() {
  test('gom sáu nguồn thành CoachContext có today và matches', () async {
    final container = testContainer(
      matches: [finishedMatch('m1', const [RackWinner.player, RackWinner.player, RackWinner.player], completedAt: testToday)],
    );
    addTearDown(container.dispose);
    container.listen(coachContextProvider, (_, _) {});
    await pumpEventQueue();
    final facts = container.read(coachContextProvider).value!.toFacts();
    expect(facts['today'], isNotNull);
    expect(((facts['matches']! as Map)['recent'] as Map)['played'], 1);
  });
}
