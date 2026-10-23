import 'dart:async';

import 'package:poolcoachai/domain/coach/coach_context.dart';

/// CoachChatBackend giả: ghi lại mọi câu hỏi; [hold] giữ câu trả lời tới khi
/// test cho.
class FakeCoachChat implements CoachChatBackend {
  FakeCoachChat({
    this.remaining = 30,
    this.replyText = 'Theo số liệu của bạn, hôm nay nên tập Phòng thủ.',
  });

  int remaining;
  String replyText;

  /// Chỉ áp dụng cho câu trả lời tiếp theo.
  bool nextInsufficient = false;

  /// Ném một lần, bởi câu trả lời tiếp theo.
  Object? nextError;

  Completer<void>? hold;

  final asked = <({String question, List<CoachChatTurn> history, Map<String, Object?> facts})>[];

  @override
  Future<CoachChatAnswer> reply(
    CoachContext context,
    List<CoachChatTurn> history,
    String question,
  ) async {
    asked.add((question: question, history: history, facts: context.toFacts()));
    final held = hold;
    if (held != null) await held.future;

    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }

    remaining -= 1;
    final insufficient = nextInsufficient;
    nextInsufficient = false;
    return (
      reply: (text: insufficient ? '' : replyText, insufficient: insufficient),
      remainingToday: remaining,
    );
  }

  @override
  Future<int> remainingToday() async => remaining;
}
