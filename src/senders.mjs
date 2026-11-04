// Lớp chọn kênh gửi: `web` có sẵn, `fcm` thêm ở P6b-2 (chưa có thì null, ★19).

/// `senderFor(channel)` trả sender của kênh, hoặc null nếu kênh chưa được cấu hình.
export function createSenders({ web, fcm = null }) {
  const byChannel = { web: web ?? null, fcm };
  return {
    senderFor(channel) {
      return Object.hasOwn(byChannel, channel) ? byChannel[channel] : null;
    },
  };
}
