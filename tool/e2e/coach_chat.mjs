// Kiểm sống dịch vụ Coach Chat (Giai đoạn B, Task 13): gọi Claude thật qua
// máy chủ server/coach-chat và Directus thật — KHÔNG PHẢI coach_chat_stub.mjs.
// Bài này tốn tiền (khoảng 4 xu Mỹ, xem docs/coach-chat.md mục 11), nên mặc
// định bỏ qua; chỉ chạy khi chủ sản phẩm đã đồng ý cho từng lượt.
//   COACH_CHAT_LIVE=1 COACH_CHAT_URL=… DIRECTUS_URL=… \
//     DIRECTUS_ADMIN_EMAIL=… DIRECTUS_ADMIN_PASSWORD=… node tool/e2e/coach_chat.mjs
import { randomBytes } from 'node:crypto';
import { deleteUserByEmail } from './throwaway_user.mjs';

if (process.env.COACH_CHAT_LIVE !== '1') {
  console.log('Bỏ qua: bài này gọi Claude thật và tốn tiền. Đặt COACH_CHAT_LIVE=1 khi chủ sản phẩm đã đồng ý.');
  process.exit(0);
}

// Biến còn lại không có mặc định (không bao giờ lỡ gọi vào bản thật mà thiếu
// thông tin) — kiểm đủ hết TRƯỚC khi gọi mạng, và chỉ in TÊN biến thiếu,
// không bao giờ in giá trị.
const REQUIRED_ENV = ['COACH_CHAT_URL', 'DIRECTUS_URL', 'DIRECTUS_ADMIN_EMAIL', 'DIRECTUS_ADMIN_PASSWORD'];
const missingEnv = REQUIRED_ENV.filter((name) => !process.env[name] || process.env[name].trim() === '');
if (missingEnv.length > 0) {
  console.error(`Thiếu biến môi trường: ${missingEnv.join(', ')}`);
  process.exit(1);
}

const COACH_CHAT_URL = process.env.COACH_CHAT_URL.replace(/\/$/, '');
const DIRECTUS_URL = process.env.DIRECTUS_URL.replace(/\/$/, '');

const PATH_HEALTHZ = '/healthz';
const PATH_QUOTA = '/v1/coach-chat/quota';
const PATH_CHAT = '/v1/coach-chat';
const PATH_BLOCKED = '/v1/coach-chat/blocked';

const QUESTION_1 = 'Hôm nay tôi nên tập gì?';
const QUESTION_2 = 'Tôi đang yếu kỹ năng nào?';

// Hình dạng khớp CoachContext.toFacts() (lib/domain/coach/coach_context.dart)
// — đã kiểm cục bộ qua server/coach-chat/src/validate.mjs thật trước khi viết
// bài này (không mạng, không commit): facts này và một history hai lượt đều
// qua parseChatRequest(). `today.category` là `safety`, `reason` là
// `weakest`, và `skillLevels.weak` nhất quán với nó, như brief Task 13 đòi.
// `skills.safety` có mastery thật (35, dưới weakBelow=55) với đủ sessions
// (3 = minSessions): bản trước round này để sessions=0/mastery=null mà vẫn
// bị liệt yếu nhất, điều app thật không bao giờ tạo ra, vì categoryMastery
// trả null khi sessions < minSessions (player_intelligence.dart:28) — không
// thể vừa null vừa "yếu nhất" (controller review, fix round 1 #M9).
// trend='notEnoughData' vì 3 buổi chưa đủ 4 buổi tối thiểu để tính xu hướng
// (categoryTrend, player_intelligence.dart:49); CategoryInsight.trend không
// bao giờ là JSON null trong toFacts() thật (coach_context.dart:76).
const FACTS = {
  skills: {
    aiming: { mastery: null, trend: null, sessions: 0 },
    position: { mastery: null, trend: null, sessions: 0 },
    breakShot: { mastery: null, trend: null, sessions: 0 },
    safety: { mastery: 35, trend: 'notEnoughData', sessions: 3 },
    kick: { mastery: null, trend: null, sessions: 0 },
    bank: { mastery: null, trend: null, sessions: 0 },
  },
  rank: null,
  currentStep: null,
  coach: {
    aiming: { total: 0, solved: 0, enough: false, recurring: null, recurringCount: 0 },
    position: { total: 0, solved: 0, enough: false, recurring: null, recurringCount: 0 },
    safety: { total: 0, solved: 0, enough: false, recurring: null, recurringCount: 0 },
    kick: { total: 0, solved: 0, enough: false, recurring: null, recurringCount: 0 },
  },
  lastSituation: null,
  skillLevels: { weak: ['safety'], strong: [], weakBelow: 55, strongFrom: 75, minSessions: 3 },
  today: {
    category: 'safety',
    reason: 'weakest',
    drillId: null,
    drillName: null,
    articleTitle: null,
    streak: 0,
    practiceMinutesThisWeek: 0,
    scheduledToday: [],
  },
  matches: {
    recent: { played: 0, won: 0, lost: 0 },
    last: null,
  },
};

let failed = 0;
function check(ok, what) {
  console.log(`${ok ? 'ĐẠT ' : 'HỎNG'}  ${what}`);
  if (!ok) failed++;
}
// Quan sát mềm (controller ruling 2): in ra để chủ sản phẩm biết, không bao
// giờ tính hỏng — câu trả lời của Claude không tất định 100%.
function note(what) {
  console.log(`GHI NHẬN  ${what}`);
}

// Khớp MAX_TURN_CHARS của server/coach-chat/src/validate.mjs (parseTurn từ
// chối mọi lượt lịch sử dài hơn số này). Clip câu trả lời 1 trước khi đưa
// vào lịch sử của câu hỏi 2 — không clip thì một câu trả lời dài làm câu
// hỏi 2 hỏng ở bước parseTurn, mất luôn phép đo cacheRead (I5, fix round 1).
const MAX_TURN_CHARS = 1000;

/// Clip ở MAX_TURN_CHARS đơn vị UTF-16, không cắt giữa một cặp surrogate —
/// cùng thuật toán với _clipTurnText (lib/domain/coach/coach_context.dart:
/// 263-268): nếu ký tự ngay trước điểm cắt là nửa đầu cặp surrogate
/// (0xD800–0xDBFF) thì lùi điểm cắt lại một đơn vị, bỏ cả cặp.
function clipTurnText(text) {
  if (text.length <= MAX_TURN_CHARS) return text;
  const lastUnit = text.charCodeAt(MAX_TURN_CHARS - 1);
  const cutAt = lastUnit >= 0xd800 && lastUnit <= 0xdbff ? MAX_TURN_CHARS - 1 : MAX_TURN_CHARS;
  return text.slice(0, cutAt);
}

/// Gọi HTTP, cố gắng đọc JSON; trả về {status, body, raw}. Không bao giờ in
/// `token` hay thân yêu cầu ra log (không có bí mật nào trong đó, nhưng vẫn
/// tránh in access token cho chắc).
async function call(url, { method = 'GET', token, body, timeoutMs = 15000 } = {}) {
  const res = await fetch(url, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs),
  });
  const raw = await res.text();
  let json = null;
  try {
    json = raw ? JSON.parse(raw) : null;
  } catch {
    json = null;
  }
  return { status: res.status, body: json, raw };
}

const email = `e2e-coach-chat-${Date.now()}@poolcoachai.example.com`;
const password = randomBytes(6).toString('hex');

try {
  // Brief bước 2: GET /healthz → "ok".
  try {
    const r = await call(`${COACH_CHAT_URL}${PATH_HEALTHZ}`);
    check(r.status === 200 && r.raw === 'ok', `GET ${PATH_HEALTHZ} → 200 "ok" (được ${r.status} "${r.raw}")`);
  } catch (err) {
    check(false, `GET ${PATH_HEALTHZ} lỗi: ${err.message}`);
  }

  // Brief bước 3: POST /v1/coach-chat không có Authorization → 401.
  try {
    const r = await call(`${COACH_CHAT_URL}${PATH_CHAT}`, { method: 'POST', body: {} });
    check(r.status === 401, `POST ${PATH_CHAT} không Authorization → 401 (được ${r.status})`);
  } catch (err) {
    check(false, `POST ${PATH_CHAT} không Authorization lỗi: ${err.message}`);
  }

  // Brief bước 4: đăng ký user thử qua Directus, rồi đăng nhập lấy access token.
  let token;
  try {
    const reg = await call(`${DIRECTUS_URL}/users/register`, {
      method: 'POST',
      body: { email, password, first_name: 'E2E Coach Chat' },
    });
    check(reg.status === 200 || reg.status === 204, `đăng ký user thử qua Directus (được ${reg.status})`);

    const login = await call(`${DIRECTUS_URL}/auth/login`, {
      method: 'POST',
      body: { email, password, mode: 'json' },
    });
    token = login.body?.data?.access_token;
    check(typeof token === 'string' && token.length > 0, 'đăng nhập user thử, nhận access token');
  } catch (err) {
    check(false, `đăng ký/đăng nhập user thử lỗi: ${err.message}`);
  }

  if (!token) {
    check(false, 'bỏ qua phần hạn mức/câu hỏi/blocked vì không có access token');
  } else {
    // Brief bước 5: GET /v1/coach-chat/quota → ghi lại limit và remainingToday.
    let limit;
    try {
      const r = await call(`${COACH_CHAT_URL}${PATH_QUOTA}`, { token });
      check(r.status === 200, `GET ${PATH_QUOTA} → 200 (được ${r.status})`);
      const shapeOk =
        typeof r.body?.limit === 'number' &&
        typeof r.body?.used === 'number' &&
        typeof r.body?.remainingToday === 'number' &&
        typeof r.body?.resetAt === 'string';
      check(shapeOk, `hình dạng ${PATH_QUOTA} đúng {limit, used, remainingToday, resetAt} (được ${JSON.stringify(r.body)})`);
      if (shapeOk) {
        limit = r.body.limit;
        note(`limit = ${r.body.limit}, remainingToday = ${r.body.remainingToday}`);
      }
    } catch (err) {
      check(false, `GET ${PATH_QUOTA} lỗi: ${err.message}`);
    }

    // Brief bước 6: câu hỏi 1 "Hôm nay tôi nên tập gì?" — facts cố định ở trên.
    let answer1Text;
    try {
      const r = await call(`${COACH_CHAT_URL}${PATH_CHAT}`, {
        method: 'POST',
        token,
        timeoutMs: 180000,
        body: { facts: FACTS, history: [], question: QUESTION_1 },
      });
      check(r.status === 200, r.status === 200 ? 'câu hỏi 1 → 200' : `câu hỏi 1 → 200 (được ${r.status}, ${JSON.stringify(r.body)})`);
      if (r.status === 200) {
        const text = r.body?.text ?? '';
        answer1Text = text;
        check(/[ăâđêôơưĂÂĐÊÔƠƯ]/.test(text), 'câu hỏi 1: câu trả lời có chữ tiếng Việt');
        note(
          text.includes('Phòng thủ')
            ? 'câu hỏi 1: câu trả lời có nhắc "Phòng thủ" (đi theo thẻ Hôm nay, spec §2)'
            : 'câu hỏi 1: câu trả lời KHÔNG nhắc "Phòng thủ" — ghi nhận, không tính hỏng (câu trả lời của Claude không tất định 100%)',
        );
        if (typeof limit === 'number') {
          check(r.body?.remainingToday === limit - 1, `câu hỏi 1: remainingToday = ${r.body?.remainingToday} (muốn ${limit - 1})`);
        } else {
          note('câu hỏi 1: không tính được remainingToday mong đợi vì thiếu limit ở bước trước');
        }
        console.log(`-- Câu trả lời 1 --\n${text}`);
        console.log(`-- usage 1 -- ${JSON.stringify(r.body?.usage)}`);
      }
    } catch (err) {
      check(false, `câu hỏi 1 lỗi: ${err.message}`);
    }

    // Brief bước 7: câu hỏi 2 "Tôi đang yếu kỹ năng nào?" — lịch sử là [câu hỏi 1, trả lời 1].
    try {
      const history =
        answer1Text === undefined
          ? []
          : [{ fromPlayer: true, text: QUESTION_1 }, { fromPlayer: false, text: clipTurnText(answer1Text) }];
      const r = await call(`${COACH_CHAT_URL}${PATH_CHAT}`, {
        method: 'POST',
        token,
        timeoutMs: 180000,
        body: { facts: FACTS, history, question: QUESTION_2 },
      });
      check(r.status === 200, r.status === 200 ? 'câu hỏi 2 → 200' : `câu hỏi 2 → 200 (được ${r.status}, ${JSON.stringify(r.body)})`);
      if (r.status === 200) {
        const text = r.body?.text ?? '';
        check(/[ăâđêôơưĂÂĐÊÔƠƯ]/.test(text), 'câu hỏi 2: câu trả lời có chữ tiếng Việt');
        const cacheRead = r.body?.usage?.cacheRead;
        note(
          typeof cacheRead === 'number' && cacheRead > 0
            ? `câu hỏi 2: cacheRead = ${cacheRead} (đệm lời dặn có hoạt động)`
            : `câu hỏi 2: cacheRead = ${cacheRead} — lời dặn hệ thống có thể dưới ngưỡng tối thiểu để đệm của model, hoặc có gì đó đổi giữa hai lượt gọi. Ghi nhận (R14), không độn thêm chữ vào lời dặn.`,
        );
        if (typeof limit === 'number') {
          check(r.body?.remainingToday === limit - 2, `câu hỏi 2: remainingToday = ${r.body?.remainingToday} (muốn ${limit - 2})`);
        } else {
          note('câu hỏi 2: không tính được remainingToday mong đợi vì thiếu limit ở bước trước');
        }
        console.log(`-- Câu trả lời 2 --\n${text}`);
        console.log(`-- usage 2 -- ${JSON.stringify(r.body?.usage)}`);
      }
    } catch (err) {
      check(false, `câu hỏi 2 lỗi: ${err.message}`);
    }

    // Brief bước 8: POST /v1/coach-chat/blocked {rule: 'unknownNumber'} → 204.
    try {
      const r = await call(`${COACH_CHAT_URL}${PATH_BLOCKED}`, {
        method: 'POST',
        token,
        body: { rule: 'unknownNumber' },
      });
      check(r.status === 204, `POST ${PATH_BLOCKED} → 204 (được ${r.status})`);
    } catch (err) {
      check(false, `POST ${PATH_BLOCKED} lỗi: ${err.message}`);
    }
  }

  console.log(`\n${failed ? `HỎNG ${failed} kiểm tra.` : 'Xong, mọi kiểm tra đạt.'}`);
} finally {
  // CASCADE của Directus tự xoá dòng hạn mức (coach_chat_usage) của user này.
  await deleteUserByEmail(email);
}
if (failed) process.exitCode = 1;
