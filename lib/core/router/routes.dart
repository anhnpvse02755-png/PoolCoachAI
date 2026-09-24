/// Hằng số đường dẫn của toàn app.
///
/// Không widget nào được viết chuỗi đường dẫn thẳng — luôn đi qua đây.
abstract final class Routes {
  // Năm tab gốc
  static const home = '/home';
  static const training = '/training';
  static const play = '/play';
  static const stats = '/stats';
  static const profile = '/profile';

  // Mở đè lên shell
  static const coach = '/coach';
  static const notifications = '/notifications';

  // Ba đường dẫn có tham số của lát dọc Phase 1.
  //
  // Hai đường đầu nằm **trong** nhánh Luyện tập của StatefulShellRoute,
  // nên đi sâu vào một bài rồi sang tab khác, quay lại vẫn thấy nguyên
  // chỗ đang dở.
  static const drillPattern = '$training/drills/:id';
  static const drillSessionPattern = '$drillPattern/session';
  static const articlePattern = '/knowledge/:id';

  /// Đường dẫn chi tiết một bài tập.
  static String drill(String id) => '$training/drills/$id';

  /// Đường dẫn buổi tập của một bài.
  static String drillSession(String id) => '${drill(id)}/session';

  /// Đường dẫn một bài kiến thức.
  static String article(String id) => '/knowledge/$id';

  // Tài khoản — mở khi chưa đăng nhập.
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  /// Mở từ link trong email; vào được cả khi đã hay chưa đăng nhập.
  static const resetPassword = '/reset-password';

  /// Đã đăng nhập thì không vào lại mấy màn này.
  static const signedOutOnly = <String>[login, register, forgotPassword];

  /// Năm tab theo đúng thứ tự hiển thị trên thanh điều hướng.
  static const tabs = <String>[home, training, play, stats, profile];

  /// Mọi đường dẫn đã đăng ký — nguồn sự thật duy nhất.
  ///
  /// Thêm route mới thì phải thêm vào đây, vì mọi kiểm thử điều hướng
  /// đều đọc từ danh sách này. Quên thì smoke test đỏ ngay, chứ không
  /// im lặng để lọt một màn không ai phủ.
  ///
  /// Đường dẫn có tham số góp mặt bằng **khuôn** của nó. Smoke test
  /// thay `:id` bằng một id mẫu rồi mới mở — làm vậy thì một route
  /// có tham số cũng không thể lọt lưới như route thường.
  static const all = <String>[
    ...tabs,
    coach,
    notifications,
    drillPattern,
    drillSessionPattern,
    articlePattern,
    login,
    register,
    forgotPassword,
    resetPassword,
  ];
}
