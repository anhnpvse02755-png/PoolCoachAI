import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cả ba nền tảng phải cho xoay ngang: màn bàn bi cần chiều ngang, và
/// mọi màn đã được dàn cho điện thoại nằm ngang.
void main() {
  test('PWA không khoá chiều xoay', () {
    final manifest = jsonDecode(
      File('web/manifest.json').readAsStringSync(),
    ) as Map<String, Object?>;
    expect(manifest['orientation'], 'any');
  });

  test('Android không khoá chiều xoay', () {
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      isNot(contains('android:screenOrientation')),
    );
  });

  test('iPhone cho xoay dọc và cả hai chiều ngang', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final iphone = RegExp(
      r'<key>UISupportedInterfaceOrientations</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist)!.group(1)!;
    for (final o in [
      'UIInterfaceOrientationPortrait',
      'UIInterfaceOrientationLandscapeLeft',
      'UIInterfaceOrientationLandscapeRight',
    ]) {
      expect(iphone, contains(o));
    }
  });
}
