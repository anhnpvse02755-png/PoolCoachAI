// Giới hạn và kiểm tra yêu cầu HTTP của Coach Chat (spec mục 7.2, R12).
// Không ghi log câu hỏi, câu trả lời, facts hay token ở đây hay ở nơi gọi.

export const MAX_BODY_BYTES = 65536;
export const MAX_FACTS_BYTES = 16384;
export const MAX_HISTORY_TURNS = 10;
export const MAX_TURN_CHARS = 1000;
export const MAX_QUESTION_CHARS = 500;

/// Lỗi yêu cầu không hợp lệ, nêu đúng trường sai để trả lỗi rõ ràng.
export class RequestError extends Error {
  constructor(field) {
    super(`Yêu cầu không hợp lệ: ${field}`);
    this.field = field;
  }
}

function isPlainObject(v) {
  return v !== null && typeof v === 'object' && !Array.isArray(v);
}

/// Kiểm tra và chuẩn hoá một lượt hội thoại: `fromPlayer` là `boolean`,
/// `text` là chuỗi không rỗng sau khi cắt khoảng trắng, tối đa
/// [MAX_TURN_CHARS] đơn vị UTF-16.
function parseTurn(turn) {
  if (!isPlainObject(turn) || typeof turn.fromPlayer !== 'boolean' || typeof turn.text !== 'string') {
    throw new RequestError('history');
  }
  const text = turn.text.trim();
  if (text.length === 0 || text.length > MAX_TURN_CHARS) {
    throw new RequestError('history');
  }
  return { fromPlayer: turn.fromPlayer, text };
}

/// Kiểm tra và chuẩn hoá thân yêu cầu `/chat` (spec mục 7.2).
///
/// `question` và mỗi `text` trong `history` được cắt khoảng trắng. Ném
/// `RequestError` nêu đúng trường sai: `body`, `facts`, `history` hay
/// `question`.
export function parseChatRequest(body) {
  if (!isPlainObject(body)) {
    throw new RequestError('body');
  }

  const { facts, history, question } = body;

  if (!isPlainObject(facts) || Buffer.byteLength(JSON.stringify(facts), 'utf8') > MAX_FACTS_BYTES) {
    throw new RequestError('facts');
  }

  if (!Array.isArray(history) || history.length > MAX_HISTORY_TURNS) {
    throw new RequestError('history');
  }
  const parsedHistory = history.map(parseTurn);

  if (typeof question !== 'string') {
    throw new RequestError('question');
  }
  const trimmedQuestion = question.trim();
  if (trimmedQuestion.length === 0 || trimmedQuestion.length > MAX_QUESTION_CHARS) {
    throw new RequestError('question');
  }

  return { facts, history: parsedHistory, question: trimmedQuestion };
}

/// Kiểm tra thân yêu cầu `/blocked-report`: chỉ tên luật, không kèm nội
/// dung câu hỏi hay câu trả lời bị chặn.
export function parseBlockedReport(body) {
  if (!isPlainObject(body) || typeof body.rule !== 'string' || !/^[A-Za-z]{1,40}$/.test(body.rule)) {
    throw new RequestError('rule');
  }
  return { rule: body.rule };
}
