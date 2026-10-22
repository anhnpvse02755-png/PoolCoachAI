import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/layout_sweep.dart';

/// Mọi route ở từng cỡ màn: điện thoại, máy tính bảng, máy tính.
const sweepConfigs = <SweepConfig>[
  (name: 'điện thoại dọc 360×640', size: Size(360, 640), textScale: 1.0),
  (
    name: 'điện thoại dọc 360×640, chữ lớn',
    size: Size(360, 640),
    textScale: 2.0,
  ),
  (name: 'máy tính bảng dọc 800×1280', size: Size(800, 1280), textScale: 1.0),
  (name: 'máy tính 1280×800', size: Size(1280, 800), textScale: 1.0),
];

void main() {
  for (final config in sweepConfigs) {
    testWidgets('${config.name}: mọi màn đã đăng nhập không tràn', (
      tester,
    ) async {
      await sweepRoutes(tester, config, signedIn: true);
    });
    testWidgets('${config.name}: mọi màn chưa đăng nhập không tràn', (
      tester,
    ) async {
      await sweepRoutes(tester, config, signedIn: false);
    });
  }
}
