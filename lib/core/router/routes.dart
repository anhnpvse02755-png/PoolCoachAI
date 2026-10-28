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
  static const equipment = '$profile/equipment';

  /// Giải đấu — trong nhánh Thi đấu, không thêm tab.
  static const tournaments = '$play/tournaments';
  static const tournamentPattern = '$play/tournaments/:id';
  static String tournament(String id) => '$play/tournaments/$id';

  // Mở đè lên shell
  static const coach = '/coach';
  static const notifications = '/notifications';

  /// Màn tình huống của Coach — mở trên màn Coach (spec Coach mục 4.2).
  static const coachSituation = '$coach/situation';

  /// Thư viện tình huống mẫu (spec Coach mục 9.4).
  static const coachLibrary = '$coach/library';

  /// Hỏi huấn luyện viên — chat tự do (spec Giai đoạn B, Task 10).
  static const coachChat = '$coach/chat';

  /// Tình huống sinh ngẫu nhiên: cùng tham số thì ra cùng thế bàn.
  static String coachGenerated(String topic, String difficulty, int seed) =>
      '$coachSituation?topic=$topic&d=$difficulty&seed=$seed';

  /// Tình huống thư viện theo id.
  static String coachLibraryEntry(String id) => '$coachSituation?lib=$id';

  /// Một mục thư viện theo thứ tự — để chụp từng mục trên Chrome.
  static String coachLibraryAt(int i) => '$coachLibrary?i=$i';

  // Ba đường dẫn có tham số của lát dọc Phase 1.
  //
  // Hai đường đầu nằm **trong** nhánh Luyện tập của StatefulShellRoute,
  // nên đi sâu vào một bài rồi sang tab khác, quay lại vẫn thấy nguyên
  // chỗ đang dở.
  static const drillPattern = '$training/drills/:id';
  static const drillSessionPattern = '$drillPattern/session';

  /// Bài kiểm tra kỹ năng của một bài — trong nhánh Luyện tập.
  static const skillTestPattern = '$training/skill-test/:id';

  /// Mô phỏng góc cắt — trong nhánh Luyện tập như các màn bài tập.
  static const simulator = '$training/simulator';

  /// Kế hoạch dọn bàn — trong nhánh Luyện tập như màn mô phỏng.
  static const planner = '$training/planner';

  /// Lộ trình — trong nhánh Luyện tập, không thêm tab.
  static const roadmap = '$training/roadmap';
  static const timer = '$training/timer';
  static const schedule = '$training/schedule';

  /// Chi tiết hạng — mở đè lên shell (spec mục 7.1).
  static const rank = '/rank';

  /// Sơ đồ mọi bài kiểm tra BU — mở đè lên shell (D12 của kế hoạch).
  static const rankLayouts = '/rank/layouts';

  /// Một sơ đồ theo thứ tự của `allLayouts()` — để chụp từng sơ đồ trên Chrome.
  static String rankLayoutAt(int i) => '$rankLayouts?i=$i';

  /// Làm bài kiểm tra BU — mở đè lên shell (spec mục 7.1).
  static const rankTest = '/rank/test';

  /// Thư viện kiến thức — mở đè lên shell như màn đọc bài.
  static const knowledge = '/knowledge';
  static const articlePattern = '/knowledge/:id';

  /// Đường dẫn chi tiết một bài tập.
  static String drill(String id) => '$training/drills/$id';

  /// Đường dẫn buổi tập của một bài.
  static String drillSession(String id) => '${drill(id)}/session';

  /// Đường dẫn bài kiểm tra kỹ năng của một bài.
  static String skillTest(String id) => '$training/skill-test/$id';

  /// Đường dẫn một bài kiến thức.
  static String article(String id) => '/knowledge/$id';

  // Tài khoản — mở khi chưa đăng nhập.
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  /// Mở từ link trong email; vào được cả khi đã hay chưa đăng nhập.
  static const resetPassword = '/reset-password';

  /// Bộ câu hỏi xác định hạng — mở đè lên shell (spec mục 7.1).
  static const onboardingRank = '/onboarding/rank';

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
    equipment,
    tournaments,
    coach,
    coachSituation,
    coachLibrary,
    coachChat,
    notifications,
    drillPattern,
    drillSessionPattern,
    skillTestPattern,
    simulator,
    planner,
    roadmap,
    timer,
    schedule,
    rank,
    rankLayouts,
    onboardingRank,
    rankTest,
    knowledge,
    articlePattern,
    login,
    register,
    forgotPassword,
    resetPassword,
  ];
}
