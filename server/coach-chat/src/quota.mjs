// Hạn mức câu hỏi mỗi ngày theo giờ Việt Nam (UTC+7, không có giờ mùa hè),
// với khoá theo từng người dùng (R10) để hai yêu cầu cùng lúc không vượt
// trần. Không log câu hỏi, câu trả lời hay facts ở đây.

import { DirectusError } from './directus.mjs';

const VN_OFFSET_MS = 7 * 60 * 60 * 1000;

/// Ngày theo giờ Việt Nam của [date], dạng `YYYY-MM-DD`.
export function vnDay(date) {
  const shifted = new Date(date.getTime() + VN_OFFSET_MS);
  const y = shifted.getUTCFullYear();
  const m = String(shifted.getUTCMonth() + 1).padStart(2, '0');
  const d = String(shifted.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/// Thời điểm (UTC) của lần 00:00 giờ Việt Nam kế tiếp sau [date], tức
/// 17:00 UTC.
export function nextResetAt(date) {
  const sameUtcDay = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), 17, 0, 0, 0));
  return sameUtcDay.getTime() > date.getTime() ? sameUtcDay : new Date(sameUtcDay.getTime() + 24 * 60 * 60 * 1000);
}

/// Id dòng hạn mức của một người dùng trong một ngày (R8).
export function usageId(userId, day) {
  return `${userId}_${day}`;
}

function emptyRow(userId, day) {
  return { id: usageId(userId, day), user: userId, day, questions: 0, input_tokens: 0, output_tokens: 0, cache_read_tokens: 0 };
}

/// Tạo bộ quản lý hạn mức. `now` được tiêm vào để test điều khiển được
/// thời gian; `limit` là số câu hỏi tối đa mỗi ngày Việt Nam.
export function createQuota({ directus, limit, now }) {
  const locks = new Map(); // userId -> đuôi chuỗi Promise hiện tại (R10)

  /// Chạy [fn] sau khi tác vụ trước đó của [userId] (nếu có) đã xong,
  /// thành công hay lỗi đều được, để các lệnh trên cùng người dùng không
  /// chồng lên nhau. Khi [fn] xong, bỏ đuôi khoá của [userId] nếu không có
  /// tác vụ mới nào xếp sau nó, để map không phình ra khi hệ thống rảnh.
  function withLock(userId, fn) {
    const prev = locks.get(userId) ?? Promise.resolve();
    const run = prev.then(fn, fn);
    locks.set(userId, run);
    run.then(
      () => { if (locks.get(userId) === run) locks.delete(userId); },
      () => { if (locks.get(userId) === run) locks.delete(userId); },
    );
    return run;
  }

  /// Hạn mức, số đã dùng, còn lại và giờ đặt lại của ngày hôm nay (giờ VN).
  async function status(userId) {
    const nowValue = now();
    const day = vnDay(nowValue);
    const row = await directus.readUsage(usageId(userId, day));
    const used = row?.questions ?? 0;
    return { limit, used, remainingToday: Math.max(limit - used, 0), resetAt: nextResetAt(nowValue).toISOString() };
  }

  /// Trừ một lượt câu hỏi của ngày hôm nay (giờ VN). Tạo dòng nếu chưa có;
  /// nếu Directus báo dòng đã được nơi khác tạo (`RECORD_NOT_UNIQUE`), đọc
  /// lại dòng đó rồi tăng tiếp, thay vì ghi đè. Nếu đọc lại vẫn không thấy
  /// dòng (không nên xảy ra, nhưng Directus đã nói có), đó là một lỗi
  /// Directus, không phải lỗi hạn mức của người chơi.
  async function take(userId) {
    return withLock(userId, async () => {
      const nowValue = now();
      const day = vnDay(nowValue);
      const id = usageId(userId, day);
      let row = await directus.readUsage(id);

      if (row === null) {
        try {
          const created = emptyRow(userId, day);
          created.questions = 1;
          await directus.createUsage(created);
          return { ok: true, day, remainingToday: Math.max(limit - 1, 0) };
        } catch (e) {
          if (!(e instanceof DirectusError) || e.code !== 'RECORD_NOT_UNIQUE') throw e;
          row = await directus.readUsage(id);
          if (row === null) throw new DirectusError(409, 'RECORD_NOT_UNIQUE');
        }
      }

      if (row.questions >= limit) {
        return { ok: false, limit, resetAt: nextResetAt(nowValue).toISOString() };
      }
      const questions = row.questions + 1;
      await directus.updateUsage(id, { questions });
      return { ok: true, day, remainingToday: Math.max(limit - questions, 0) };
    });
  }

  /// Hoàn một lượt đã trừ cho đúng ngày [day] (giờ VN lúc trừ), kể cả khi
  /// hiện tại đã sang ngày khác. Không bao giờ xuống dưới 0.
  async function refund(userId, day) {
    return withLock(userId, async () => {
      const id = usageId(userId, day);
      const row = await directus.readUsage(id);
      if (row === null) return;
      await directus.updateUsage(id, { questions: Math.max(row.questions - 1, 0) });
    });
  }

  /// Cộng số token đã dùng vào dòng của ngày [day] (giờ VN lúc câu hỏi
  /// được trừ lượt).
  async function addUsage(userId, day, { input, output, cacheRead }) {
    return withLock(userId, async () => {
      const id = usageId(userId, day);
      const row = await directus.readUsage(id);
      if (row === null) return;
      await directus.updateUsage(id, {
        input_tokens: row.input_tokens + input,
        output_tokens: row.output_tokens + output,
        cache_read_tokens: row.cache_read_tokens + cacheRead,
      });
    });
  }

  return { status, take, refund, addUsage };
}
