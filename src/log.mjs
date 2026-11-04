// Băm id người dùng để ghi vào dòng nhật ký mà không lộ id thật (R17): 16
// ký tự hex đầu của SHA-256(id). Không đệm, không đảo ngược được.

import { createHash } from 'node:crypto';

/// Băm [id] người dùng thành 16 ký tự hex đầu của SHA-256, dùng cho nhật ký
/// một dòng mỗi yêu cầu — không bao giờ ghi id thật.
export function hashUserId(id) {
  return createHash('sha256').update(id, 'utf8').digest('hex').slice(0, 16);
}
