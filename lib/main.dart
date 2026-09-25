import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // URL dạng /training/drills/d1 thay vì /#/training/…: link đặt lại mật
  // khẩu trong email mang ?token=…, và dạng hash làm token lạc chỗ.
  usePathUrlStrategy();

  // Bộ chứa dựng ở đây rồi truyền xuống, không để ProviderScope tự
  // dựng: seed phải nằm trong DB **trước** khi màn hình đầu tiên đọc,
  // nên phải cầm được đúng bộ chứa đó mà nạp.
  final container = ProviderContainer();
  await loadSeed(container);
  await restoreSession(container);
  startSync(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PoolCoachApp(),
    ),
  );
}
