import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ba luật kiến trúc mà chỉ đọc mã thì không ai nhớ nổi.
///
/// Cả ba đều thuộc loại vi phạm êm ru: mã vẫn chạy, test khác vẫn
/// xanh, chỉ có kiến trúc lặng lẽ trôi về chỗ mà tài liệu thiết kế đã
/// bác bỏ. Kiểm bằng cách đọc chính mã nguồn.
void main() {
  List<File> dartFilesIn(String path) => Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// Bỏ dòng chỉ có chú thích, để chữ tiếng Việt trong chú thích không
  /// bị tính là chuỗi hiển thị.
  String codeOnly(String source) => source
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  test('ngoài upsertSeed, không nơi nào trong lib đọc thẳng dữ liệu seed', () {
    final offenders = <String>[];
    for (final file in dartFilesIn('lib')) {
      final path = file.path.replaceAll(r'\', '/');
      if (path.contains('lib/data/seed/')) continue;
      if (path.endsWith('lib/data/database/upsert_seed.dart')) continue;

      final source = file.readAsStringSync();
      if (source.contains('seedDrills') || source.contains('seedKnowledge')) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'đọc thẳng seed là quay lại có hai nguồn sự thật — dữ liệu '
          'seed chỉ được vào app qua upsertSeed()',
    );
  });

  test('không nơi nào gọi invalidate hay refresh để làm mới màn hình', () {
    final offenders = <String>[];
    for (final file in dartFilesIn('lib')) {
      final source = codeOnly(file.readAsStringSync());
      if (source.contains('.invalidate(') || source.contains('.refresh(')) {
        offenders.add(file.path.replaceAll(r'\', '/'));
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'màn hình đổi theo stream về mặt cấu trúc. Gọi tay là biến '
          'việc đó thành kỷ luật con người — quên một chỗ là màn hình '
          'hiện số cũ mà không test nào biết',
    );
  });

  test('DB mở được trên web: có DriftWebOptions và đủ file trong web/', () {
    // Test chạy bằng NativeDatabase nên không bao giờ đi qua nhánh web.
    // Thiếu `web:` thì drift_flutter ném ArgumentError ngay lúc mở DB
    // trong trình duyệt — build vẫn xanh, app thì chết ở màn đầu tiên.
    final source = codeOnly(
      File('lib/data/database/database.dart').readAsStringSync(),
    );
    final calls = RegExp(r'driftDatabase\(([\s\S]*?)\);').allMatches(source);

    expect(calls, isNotEmpty, reason: 'không tìm thấy chỗ mở DB');
    for (final call in calls) {
      expect(
        call[1],
        contains('DriftWebOptions('),
        reason: 'driftDatabase() thiếu `web:` — app vỡ trên Chrome',
      );
    }

    final assets = RegExp(r"Uri\.parse\('([^']+)'\)")
        .allMatches(source)
        .map((m) => m[1]!)
        .toList();
    expect(assets, containsAll(['sqlite3.wasm', 'drift_worker.js']));
    for (final asset in assets) {
      expect(
        File('web/$asset').existsSync(),
        isTrue,
        reason: 'web/$asset không có — build web sẽ không mang theo nó',
      );
    }
  });

  test('không màn hình nào chứa chuỗi tiếng Việt viết thẳng', () {
    // Ký tự chỉ có trong tiếng Việt, đủ để bắt mọi câu thật.
    final vietnamese = RegExp(
      r"'[^']*[ăâđêôơưàáảãạầấẩẫậằắẳẵặèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ][^']*'",
      caseSensitive: false,
    );
    final offenders = <String>[];

    for (final file in [
      ...dartFilesIn('lib/features'),
      ...dartFilesIn('lib/core/widgets'),
    ]) {
      final matches = vietnamese.allMatches(codeOnly(file.readAsStringSync()));
      for (final match in matches) {
        offenders.add('${file.path.replaceAll(r'\', '/')}: ${match[0]}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'mọi chữ hiển thị phải đi qua Vi, để đổi cách gọi một '
          'thuật ngữ chỉ phải sửa một dòng thay vì lục khắp các màn',
    );
  });
}
