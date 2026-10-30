// Tạm: Task 8 thay bằng planner thật (helper Dart), Task 11 thay bằng scheduler thật.
// Planner giả luôn không khoẻ và info() từ chối, để image phát hành từ commit này
// không thể báo helper ok trong khi không có gì chạy.
export function createPlaceholderPlanner() {
  return {
    healthy: false,
    info: async () => { throw new Error('planner not wired (Task 8)'); },
    close: () => {},
  };
}
export function createPlaceholderScheduler() {
  return { lastCycleAt: null, start: () => {}, stop: () => {} };
}
