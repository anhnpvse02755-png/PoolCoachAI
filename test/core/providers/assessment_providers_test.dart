import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/rank.dart';

import '../../support/fake_auth.dart';

void main() {
  test('hạng của người đang đăng nhập; đăng xuất thì không còn', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final auth = FakeAuthRepository.signedIn();
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      authRepositoryProvider.overrideWithValue(auth),
      nowProvider.overrideWithValue(() => DateTime(2026, 10, 14)),
    ]);
    addTearDown(container.dispose);

    container.listen(playerRankProvider, (_, _) {});
    await pumpEventQueue();
    expect(container.read(playerRankProvider).value, isNull);

    await container.read(assessmentRepositoryProvider)!.saveQuestionnaire(
        chosen: Rank.g, suggested: Rank.g,
        answers: QuestionnaireAnswers([0, 0, 0, 0, 2, 0, 0, 0]));
    await pumpEventQueue();
    expect(container.read(playerRankProvider).value!.rank, Rank.g);

    auth.emit(const SignedOut());
    await pumpEventQueue();
    expect(container.read(assessmentRepositoryProvider), isNull);
    expect(container.read(playerRankProvider).value, isNull);
  });
}
