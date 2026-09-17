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

  /// Năm tab theo đúng thứ tự hiển thị trên thanh điều hướng.
  static const tabs = <String>[home, training, play, stats, profile];
}
