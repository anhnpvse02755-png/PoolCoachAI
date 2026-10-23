import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_stats.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/coach_chat_fixtures.dart';

/// Mọi khoá (và khoá lồng bên trong) của một `Map`/`List` JSON.
Set<String> allKeys(Object? v) => switch (v) {
      Map() => {for (final e in v.entries) ...{e.key as String, ...allKeys(e.value)}},
      List() => {for (final x in v) ...allKeys(x)},
      _ => <String>{},
    };

void main() {
  test('lời dặn hệ thống giải thích mọi khoá và mọi giá trị mà facts có thể gửi', () {
    final prompt = File('server/coach-chat/src/prompt.mjs').readAsStringSync();
    final names = <String>{
      ...allKeys(fullCoachContext().toFacts()),
      for (final values in <List<Enum>>[SkillCategory.values, CoachTopic.values, StepKind.values,
          StepStatus.values, PickReason.values, MatchShotType.values, MatchShotOutcome.values, PositionOutcome.values,
          SkillTrend.values, CoachAttemptOutcome.values, CoachFaultGroup.values, PoolGameType.values])
        for (final v in values) v.name,
    };
    for (final n in names) {
      expect(RegExp('(?<![A-Za-z])${RegExp.escape(n)}(?![A-Za-z])').hasMatch(prompt), isTrue, reason: '$n chưa có trong lời dặn');
    }

    // Rank dùng tên một chữ (k, i, h, g, ...), lẫn vào chữ Việt có dấu nên
    // kiểm tra "cả từ" ở trên luôn đúng dù lời dặn không hề nhắc tới nó
    // (ví dụ "a" khớp cuối "bi-a", "d" khớp đầu "dữ"). Kiểm tra thẳng là
    // lời dặn liệt kê đủ danh sách hạng, phân cách bằng dấu phẩy.
    final rankNames = Rank.values.map((r) => r.name).toList();
    expect(
      prompt,
      contains(rankNames.sublist(0, rankNames.length - 1).join(', ')),
      reason: 'danh sách hạng chưa có trong lời dặn',
    );
    expect(prompt, contains(rankNames.last), reason: '${rankNames.last} chưa có trong lời dặn');

    for (final c in SkillCategory.values) {
      expect(prompt, contains(Vi.skill(c)));
    }
  });
}
