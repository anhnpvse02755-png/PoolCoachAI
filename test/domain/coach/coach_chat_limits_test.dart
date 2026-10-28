import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/coach_chat_fixtures.dart';
import '../../support/match_fixtures.dart';

/// Giá trị của `export const NAME = N;` trong mã dịch vụ. Không tìm thấy thì
/// test đỏ — đổi tên hằng bên dịch vụ không được làm phép so lặng lẽ biến mất.
int serverConstant(String source, String name) {
  final match = RegExp('^export const ${RegExp.escape(name)} = (\\d+);', multiLine: true).firstMatch(source);
  expect(match, isNotNull, reason: '$name chưa có trong validate.mjs');
  return int.parse(match!.group(1)!);
}

void main() {
  // App và dịch vụ phải cùng giới hạn: app gửi quá giới hạn thì dịch vụ trả
  // 400 và mọi câu hỏi sau đều hỏng (M5, review cuối; xem ruling F2).
  test('giới hạn lịch sử, độ dài một lượt và độ dài câu hỏi khớp với validate.mjs', () {
    final source = File('server/coach-chat/src/validate.mjs').readAsStringSync();
    expect(serverConstant(source, 'MAX_HISTORY_TURNS'), coachChatHistoryTurns);
    expect(serverConstant(source, 'MAX_TURN_CHARS'), coachChatMaxTurnChars);
    expect(serverConstant(source, 'MAX_QUESTION_CHARS'), coachChatMaxQuestion);
  });

  test('facts đầy đủ với 10 trận nhiều cú vẫn dưới MAX_FACTS_BYTES', () {
    final max = serverConstant(File('server/coach-chat/src/validate.mjs').readAsStringSync(), 'MAX_FACTS_BYTES');
    final ten = matchesWeakAt(SkillCategory.aiming, count: 10, at: DateTime(2026, 10, 20));
    final facts = contextWithMatches(ten).toFacts();
    expect(((facts['matches']! as Map)['analysis']! as Map)['matches'], 10);
    expect(utf8.encode(jsonEncode(facts)).length, lessThan(max));
  });
}
