// Gọi Claude cho Coach Chat: stream, thinking adaptive, effort thấp, dự phòng phía máy
// chủ, đọc stop_reason trước khi đọc nội dung (R17), chuẩn hoá Unicode NFC (ruling Task 2:
// bộ lọc của app chặn chữ tổ hợp NFD). Không log câu hỏi, câu trả lời hay facts ở đây.

import Anthropic from '@anthropic-ai/sdk';
import { SYSTEM_PROMPT } from './prompt.mjs';

export const CLAUDE_MAX_TOKENS = 4000;
export const FALLBACK_BETA = 'server-side-fallback-2026-07-01';

function nfc(text) {
  return text.normalize('NFC');
}

function textBlock(text) {
  return { type: 'text', text: nfc(text) };
}

/// Dựng `messages` cho `/v1/messages` từ [history], [facts] và [question] (spec mục 7.4):
/// mỗi lượt lịch sử thành một khối text, vai `user` khi `fromPlayer`; lượt trợ lý ở đầu bị
/// bỏ (yêu cầu phải bắt đầu bằng `user`); các lượt liền kề cùng vai được gộp vào một tin;
/// tin cuối (vai `user`) có thêm hai khối `<facts>` và `<question>`. Mọi chữ gửi đi được
/// chuẩn hoá NFC.
export function buildMessages(history, facts, question) {
  const turns = [];
  for (const turn of history) {
    if (turns.length === 0 && !turn.fromPlayer) continue; // bỏ lượt trợ lý ở đầu
    turns.push(turn);
  }

  const messages = [];
  for (const turn of turns) {
    const role = turn.fromPlayer ? 'user' : 'assistant';
    if (messages.length > 0 && messages[messages.length - 1].role === role) {
      messages[messages.length - 1].content.push(textBlock(turn.text));
    } else {
      messages.push({ role, content: [textBlock(turn.text)] });
    }
  }

  const factsBlock = textBlock(`<facts>\n${JSON.stringify(facts)}\n</facts>`);
  const questionBlock = textBlock(`<question>\n${question}\n</question>`);
  if (messages.length > 0 && messages[messages.length - 1].role === 'user') {
    messages[messages.length - 1].content.push(factsBlock, questionBlock);
  } else {
    messages.push({ role: 'user', content: [factsBlock, questionBlock] });
  }

  return messages;
}

/// Phân loại lỗi từ `client.beta.messages.stream(...).finalMessage()` thành mã lỗi HTTP
/// trả cho app, cụ thể nhất trước (`APIConnectionError` là lớp con của `APIError` trong SDK
/// TS, nên phải xét trước). Lỗi không phải của SDK Anthropic (ví dụ lỗi lập trình) trả `null`.
export function classifyClaudeError(err) {
  if (err instanceof Anthropic.RateLimitError) return { status: 503, code: 'busy' };
  if (err instanceof Anthropic.APIConnectionError) return { status: 503, code: 'unavailable' };
  if (err instanceof Anthropic.APIError) {
    return err.status === 529 || err.type === 'overloaded_error' ? { status: 503, code: 'busy' } : { status: 502, code: 'upstream' };
  }
  return null;
}

/// Tạo client Claude cho Coach Chat. [fetch] được tiêm vào để test không gọi Claude thật
/// (global-constraints: tests offline).
export function createClaude({ apiKey, model, effort, fallbacks, fetch, maxRetries = 1, timeout = 60_000 }) {
  const client = new Anthropic({ apiKey, fetch, maxRetries, timeout });

  /// Hỏi Claude một câu, với [facts], [history] và [question] (spec mục 7.4, 7.7). Đọc
  /// `stop_reason` trước `content` (R17): `refusal` hay `max_tokens` không trả lại phần chữ
  /// đã viết dở, tránh câu trả lời cụt bị hiểu nhầm là đầy đủ.
  async function ask({ facts, history, question }) {
    const stream = client.beta.messages.stream({
      model,
      max_tokens: CLAUDE_MAX_TOKENS,
      thinking: { type: 'adaptive' },
      output_config: { effort },
      ...(fallbacks ? { betas: [FALLBACK_BETA], fallbacks: 'default' } : {}),
      system: [{ type: 'text', text: SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } }],
      messages: buildMessages(history, facts, nfc(question)),
    });
    const message = await stream.finalMessage();

    const usage = {
      input: message.usage.input_tokens + (message.usage.cache_creation_input_tokens ?? 0),
      output: message.usage.output_tokens,
      cacheRead: message.usage.cache_read_input_tokens ?? 0,
      cacheWrite: message.usage.cache_creation_input_tokens ?? 0,
    };

    const stopReason = message.stop_reason;
    if (stopReason !== 'end_turn') {
      return { kind: stopReason === 'refusal' ? 'refused' : 'truncated', text: '', model: message.model, stopReason, usage };
    }

    const text = message.content
      .filter((block) => block.type === 'text')
      .map((block) => block.text)
      .join('')
      .trim();
    return { kind: 'answer', text: nfc(text), model: message.model, stopReason, usage };
  }

  return { ask };
}
