import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_theme.dart';

/// Widget gốc của PoolCoachAI.
///
/// Router được dựng một lần trong [initState] chứ không phải mỗi lần
/// build — GoRouter nhớ vị trí điều hướng, dựng lại mỗi build sẽ ném
/// người dùng về màn gốc mỗi khi widget cha vẽ lại.
class PoolCoachApp extends StatefulWidget {
  const PoolCoachApp({this.router, super.key});

  /// Cho phép truyền router sẵn có. Kiểm thử dùng lối này để tự điều
  /// khiển điều hướng; chạy thật thì để trống và app tự dựng.
  final GoRouter? router;

  @override
  State<PoolCoachApp> createState() => _PoolCoachAppState();
}

class _PoolCoachAppState extends State<PoolCoachApp> {
  late final GoRouter _router = widget.router ?? createAppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: Vi.appName,
      theme: AppTheme.dark(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
