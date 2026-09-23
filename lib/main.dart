import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/bootstrap.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bộ chứa dựng ở đây rồi truyền xuống, không để ProviderScope tự
  // dựng: seed phải nằm trong DB **trước** khi màn hình đầu tiên đọc,
  // nên phải cầm được đúng bộ chứa đó mà nạp.
  final container = ProviderContainer();
  await loadSeed(container);
  await restoreSession(container);

  // Đồng bộ chạy nền suốt đời app; màn hình chỉ đọc Drift.
  container.read(syncServiceProvider).start();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PoolCoachApp(),
    ),
  );
}
