import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_theme.dart';

/// Widget gốc của PoolCoachAI.
///
/// Router được khởi tạo một lần trong `State` chứ không phải mỗi lần
/// build — GoRouter nhớ vị trí điều hướng, dựng lại mỗi build sẽ ném
/// người dùng về màn gốc mỗi khi widget cha vẽ lại.
class PoolCoachApp extends ConsumerStatefulWidget {
  const PoolCoachApp({this.router, super.key});

  /// Cho phép truyền router sẵn có. Kiểm thử dùng lối này để tự điều
  /// khiển điều hướng; chạy thật thì để trống và app tự dựng.
  final GoRouter? router;

  @override
  ConsumerState<PoolCoachApp> createState() => _PoolCoachAppState();
}

class _PoolCoachAppState extends ConsumerState<PoolCoachApp> {
  /// Chỉ dispose router do chính widget này dựng.
  ///
  /// Router truyền từ ngoài vào thuộc về người gọi — kiểm thử tự dựng
  /// rồi tự dọn. Dispose hộ sẽ giết router ngay dưới chân người gọi.
  bool get _ownsRouter => widget.router == null;
  late final GoRouter _router =
      widget.router ?? createAppRouter(auth: ref.read(authGateProvider));

  @override
  void dispose() {
    if (_ownsRouter) {
      _router.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: Vi.appName,
      theme: AppTheme.dark(),
      routerConfig: _router,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
    );
  }
}
