import { test } from 'node:test';
import assert from 'node:assert/strict';
import { SYSTEM_PROMPT } from '../src/prompt.mjs';

test('lời dặn hệ thống cố định, đủ luật và thuật ngữ của chủ sản phẩm', () => {
  for (const must of ['<facts>', '<question>', 'chưa đủ dữ liệu', 'tối ưu', 'BHE', 'Xem đáp án', 'Hôm nay', 'chữ số',
    'A băng', 'Cân bi', 'Đánh trô bi', 'Đánh cu lê', 'Đánh đứng bi', 'Đánh tâm tiến', 'Chết cái', 'Bi ảo', 'Bi cái',
    'Áp phê', 'đầu cơ', 'Ném', 'Bị đui', 'bắt đui', 'Chấm', 'băng dài trên', 'băng ngắn trái', 'Nhảy bi', 'Mát xê',
    'Ăn bi', 'Dựng cơ', 'Dội băng', 'Kế hoạch dọn bàn', 'Trơn', 'Sọc']) {
    assert.ok(SYSTEM_PROMPT.includes(must), must);
  }
  assert.ok(!SYSTEM_PROMPT.includes('${') && !SYSTEM_PROMPT.includes('`'));
});

test('final fix wave (I2a/M7): hai câu CÁCH TRẢ LỜI mới, bốn từ sai mới, bỏ cụm "lệch ... đầu cơ" cũ', () => {
  assert.ok(
    SYSTEM_PROMPT.includes('Không đánh số các ý hay các bước; cần liệt kê thì dùng gạch đầu dòng.'),
    'thiếu câu "không đánh số"',
  );
  assert.ok(
    SYSTEM_PROMPT.includes('Không nhắc lại con số người chơi nêu trong câu hỏi nếu nó không có trong dữ kiện.'),
    'thiếu câu "không nhắc lại con số người chơi nêu"',
  );
  for (const wrong of ['bi băng', 'bi lăn theo', 'cú dừng bi', 'làm đui']) {
    assert.ok(SYSTEM_PROMPT.includes(`"${wrong}"`), `thiếu từ sai "${wrong}" trong danh sách Không dùng`);
  }
  assert.ok(
    !SYSTEM_PROMPT.includes('lệch 0,5 / 1 / 2 đầu cơ'),
    'cụm "lệch 0,5 / 1 / 2 đầu cơ" vẫn còn — đưa số cấm thẳng ra trước mặt model (M7)',
  );
});
