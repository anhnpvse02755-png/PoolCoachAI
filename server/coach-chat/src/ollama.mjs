import { SYSTEM_PROMPT } from './prompt.mjs';

export const OLLAMA_NUM_CTX = 8192;
export const OLLAMA_NUM_PREDICT = 1024;

function nfc(text) {
  return text.normalize('NFC');
}

function textBlock(text) {
  return nfc(text);
}

export function buildMessages(history, facts, question) {
  const turns = [];
  for (const turn of history) {
    if (turns.length === 0 && !turn.fromPlayer) continue;
    turns.push(turn);
  }

  const messages = [];
  for (const turn of turns) {
    const role = turn.fromPlayer ? 'user' : 'assistant';
    const content = textBlock(turn.text);
    if (messages.length > 0 && messages[messages.length - 1].role === role) {
      messages[messages.length - 1].content += `\n${content}`;
    } else {
      messages.push({ role, content });
    }
  }

  const finalContent = [
    `<facts>\n${JSON.stringify(facts)}\n</facts>`,
    `<question>\n${nfc(question)}\n</question>`,
  ].join('\n');
  if (messages.length > 0 && messages[messages.length - 1].role === 'user') {
    messages[messages.length - 1].content += `\n${finalContent}`;
  } else {
    messages.push({ role: 'user', content: finalContent });
  }
  return messages;
}

export class OllamaError extends Error {
  constructor(status) {
    super(`Ollama returned HTTP ${status}`);
    this.status = status;
  }
}

export class OllamaUnavailableError extends Error {}

export function classifyOllamaError(err) {
  if (err instanceof OllamaError) {
    return err.status === 429 || err.status === 503
      ? { status: 503, code: 'busy' }
      : { status: 502, code: 'upstream' };
  }
  if (err instanceof OllamaUnavailableError) {
    return { status: 503, code: 'unavailable' };
  }
  return null;
}

export function createOllama({ baseUrl, model, fetch = globalThis.fetch, deadlineMs = 120_000 }) {
  async function ask({ facts, history, question }) {
    let response;
    try {
      response = await fetch(new URL('/api/chat', `${baseUrl}/`), {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        signal: AbortSignal.timeout(deadlineMs),
        body: JSON.stringify({
          model,
          stream: false,
          messages: [
            { role: 'system', content: SYSTEM_PROMPT },
            ...buildMessages(history, facts, question),
          ],
          options: {
            temperature: 0.2,
            num_ctx: OLLAMA_NUM_CTX,
            num_predict: OLLAMA_NUM_PREDICT,
          },
          keep_alive: '5m',
        }),
      });
    } catch (err) {
      if (err instanceof TypeError || err?.name === 'AbortError' || err?.name === 'TimeoutError') {
        throw new OllamaUnavailableError();
      }
      throw err;
    }

    if (!response.ok) throw new OllamaError(response.status);
    const result = await response.json();
    const text = result.message?.content;
    const stopReason = result.done_reason ?? 'stop';
    const usage = {
      input: result.prompt_eval_count ?? 0,
      output: result.eval_count ?? 0,
      cacheRead: 0,
      cacheWrite: 0,
    };

    if (stopReason === 'length') {
      return { kind: 'truncated', text: '', model: result.model ?? model, stopReason, usage };
    }
    if (typeof text !== 'string' || text.trim().length === 0) {
      throw new Error('Ollama returned an empty response');
    }
    return { kind: 'answer', text: nfc(text.trim()), model: result.model ?? model, stopReason, usage };
  }

  return { ask };
}
