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
