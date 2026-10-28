import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ký tự chỉ có trong tiếng Việt, đủ để bắt mọi câu thật.
final vietnameseLiteral = RegExp(
  r"'[^']*[ăâđêôơưàáảãạầấẩẫậằắẳẵặèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ][^']*'",
  caseSensitive: false,
);

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
    expect(assets, containsAll(['/sqlite3.wasm', '/drift_worker.js']),
        reason: 'phải là đường dẫn tuyệt đối: app dùng URL dạng đường dẫn, '
            'nên đường dẫn tương đối bị hiểu theo trang đang mở, và mở '
            'thẳng /training/drills/d1 sẽ tải nhầm index.html thay cho wasm');
    for (final asset in assets) {
      expect(
        File('web$asset').existsSync(),
        isTrue,
        reason: 'web$asset không có — build web sẽ không mang theo nó',
      );
    }
  });

  test('app dùng URL dạng đường dẫn, để link trong email mở đúng màn', () {
    final main = codeOnly(File('lib/main.dart').readAsStringSync());
    expect(main, contains('usePathUrlStrategy()'),
        reason: 'link đặt lại mật khẩu có dạng /reset-password?token=…; '
            'ở dạng hash, Directus chèn ?token vào trước dấu #');
  });

  test('không màn hình nào chứa chuỗi tiếng Việt viết thẳng', () {
    final offenders = <String>[];

    for (final file in [
      ...dartFilesIn('lib/features'),
      ...dartFilesIn('lib/core/widgets'),
    ]) {
      final matches = vietnameseLiteral.allMatches(codeOnly(file.readAsStringSync()));
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

  test('lib/ không được chứa thư mục test', () {
    final libTest = Directory('lib/test');
    expect(
      libTest.existsSync(),
      isFalse,
      reason: 'test/support/ phải nằm trong test/, không phải lib/test/ — '
          'file test không bao giờ được ship cùng app',
    );
  });

  test('lib/ không import package:poolcoachai/test/', () {
    final offenders = <String>[];
    for (final file in dartFilesIn('lib')) {
      if (file.readAsStringSync().contains("package:poolcoachai/test/")) {
        offenders.add(file.path.replaceAll(r'\', '/'));
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'import test từ lib/ là ship test cùng app — '
          'test/support/ chỉ được dùng trong thư mục test/',
    );
  });

  test('lõi hình học bàn không phụ thuộc Flutter', () {
    final offenders = [
      for (final file in dartFilesIn('lib/domain/table_geometry'))
        if (codeOnly(file.readAsStringSync()).contains('package:flutter'))
          file.path.replaceAll(r'\', '/'),
    ];

    expect(
      offenders,
      isEmpty,
      reason: 'Planner và test dùng thẳng lõi này; kéo Flutter vào thì lõi '
          'không còn là logic thuần, và mọi phép tính phải chạy qua widget',
    );
  });

  test('lõi vật lý bàn không phụ thuộc Flutter', () {
    final files = dartFilesIn('lib/domain/table_physics');
    final offenders = [
      for (final file in files)
        if (codeOnly(file.readAsStringSync()).contains('package:flutter'))
          file.path.replaceAll(r'\', '/'),
    ];

    expect(files, isNotEmpty);
    expect(
      offenders,
      isEmpty,
      reason: 'màn mô phỏng và Planner dùng chung lõi này; kéo Flutter vào '
          'thì không còn chạy và đo hiệu năng được trên Dart VM thuần',
    );
  });

  test('lõi hình học bàn không import lõi vật lý', () {
    // table_physics đã import table_geometry (Vec2, TableSpec, Stroke…).
    // Chiều ngược lại là vòng phụ thuộc: sửa lõi vật lý thì phải dựng lại cả
    // lõi hình học, và Planner không còn biết tầng nào là nền.
    final offenders = [
      for (final file in dartFilesIn('lib/domain/table_geometry'))
        if (codeOnly(file.readAsStringSync())
            .contains('package:poolcoachai/domain/table_physics/'))
          file.path.replaceAll(r'\', '/'),
    ];

    expect(
      offenders,
      isEmpty,
      reason: 'table_geometry là nền của table_physics; lõi vật lý được '
          'import hình học, không có chiều ngược lại (spec 2026-10-07 mục 8)',
    );
  });

  test('lõi Planner không phụ thuộc Flutter', () {
    final files = dartFilesIn('lib/domain/planner');
    final offenders = [
      for (final file in files)
        if (codeOnly(file.readAsStringSync()).contains('package:flutter'))
          file.path.replaceAll(r'\', '/'),
    ];

    expect(files, isNotEmpty);
    expect(
      offenders,
      isEmpty,
      reason: 'Planner phải chạy và đo được trên Dart VM thuần, và sau này '
          'chuyển sang Web Worker hay điện thoại mà không đổi lõi (spec mục 2)',
    );
  });

  test('lõi đánh giá không phụ thuộc Flutter', () {
    final files = dartFilesIn('lib/domain/assessment');
    final offenders = [
      for (final file in files)
        if (codeOnly(file.readAsStringSync()).contains('package:flutter'))
          file.path.replaceAll(r'\', '/'),
    ];

    expect(files, isNotEmpty);
    expect(
      offenders,
      isEmpty,
      reason: 'luật hạng và bộ chấm BU phải chạy và test được trên Dart VM '
          'thuần (spec 2026-10-14 mục 5)',
    );
  });

  test('lõi Lộ trình không phụ thuộc Flutter', () {
    final files = dartFilesIn('lib/domain/roadmap');
    final offenders = [
      for (final file in files)
        if (codeOnly(file.readAsStringSync()).contains('package:flutter'))
          file.path.replaceAll(r'\', '/'),
    ];

    expect(files, isNotEmpty);
    expect(
      offenders,
      isEmpty,
      reason: 'cách suy bước, ước lượng ngày và thành tích phải chạy và test '
          'được trên Dart VM thuần (spec 2026-10-15 mục 4)',
    );
  });

  test('lõi Coach không phụ thuộc Flutter', () {
    final files = dartFilesIn('lib/domain/coach');
    final offenders = [
      for (final file in files)
        if (codeOnly(file.readAsStringSync()).contains('package:flutter'))
          file.path.replaceAll(r'\', '/'),
    ];

    expect(files, isNotEmpty);
    expect(
      offenders,
      isEmpty,
      reason: 'chấm cú, gợi ý, bộ sinh và thẻ gợi ý phải chạy và test được '
          'trên Dart VM thuần, và chạy giống hệt trên web, Android, iOS '
          '(spec 2026-10-21 mục 5)',
    );
  });

  test('lõi tỉ lệ thắng theo cơ không phụ thuộc Flutter', () {
    final files = dartFilesIn('lib/domain/cue_performance');
    final offenders = [
      for (final file in files)
        if (codeOnly(file.readAsStringSync()).contains('package:flutter'))
          file.path.replaceAll(r'\', '/'),
    ];

    expect(files, isNotEmpty);
    expect(
      offenders,
      isEmpty,
      reason: 'cách tính tỉ lệ thắng và kết luận cơ hợp nhất phải chạy và '
          'test được trên Dart VM thuần',
    );
  });

  test('lõi phân tích trận không phụ thuộc Flutter, không dùng Vi, không có chuỗi tiếng Việt', () {
    final files = dartFilesIn('lib/domain/match_analysis');
    final offenders = <String>[];
    for (final file in files) {
      final code = codeOnly(file.readAsStringSync());
      final path = file.path.replaceAll(r'\', '/');
      if (code.contains('package:flutter')) offenders.add('$path: flutter');
      if (code.contains('core/strings/vi.dart')) offenders.add('$path: Vi');
      for (final m in vietnameseLiteral.allMatches(code)) {
        offenders.add('$path: ${m[0]}');
      }
    }

    expect(files, isNotEmpty);
    expect(
      offenders,
      isEmpty,
      reason: 'phân tích trận chỉ trả enum và số đếm; câu chữ nằm ở Vi và '
          'phải chạy được trên Dart VM thuần',
    );
  });

  test('lõi Skill Test không phụ thuộc Flutter, không dùng Vi, không có chuỗi tiếng Việt, không dựng PlayerRank', () {
    final files = dartFilesIn('lib/domain/skill_test');
    final offenders = <String>[];
    for (final file in files) {
      final code = codeOnly(file.readAsStringSync());
      final path = file.path.replaceAll(r'', '/');
      for (final banned in [
        'package:flutter',
        'core/strings/vi.dart',
        'PlayerRank(',
        'player_rank.dart',
        'rank_rules.dart',
      ]) {
        if (code.contains(banned)) offenders.add('$path: $banned');
      }
      for (final m in vietnameseLiteral.allMatches(code)) {
        offenders.add('$path: ${m[0]}');
      }
    }

    expect(files, isNotEmpty);
    expect(
      offenders,
      isEmpty,
      reason: 'cổng mở cấp do luật quyết định, không đổi hạng (README quy tắc 2; spec skill test mục 2)',
    );
  });

  test('app không gọi thẳng Claude và không chứa khoá Anthropic', () {
    final files = dartFilesIn('lib');
    expect(
      files.any((f) => f.path.replaceAll(r'\', '/').endsWith('lib/data/remote/coach_chat_client.dart')),
      isTrue,
      reason: 'bài test này chỉ có nghĩa khi nó thực sự quét '
          'coach_chat_client.dart — file đó mất khỏi lib/ thì test này '
          'xanh một cách vô nghĩa',
    );

    final offenders = [
      for (final f in files)
        if (RegExp(
          r'anthropic\.com|sk-ant-|ANTHROPIC_API_KEY|x-api-key',
          caseSensitive: false,
        ).hasMatch(f.readAsStringSync()))
          f.path.replaceAll(r'\', '/'),
    ];
    expect(offenders, isEmpty,
        reason: 'spec 2026-10-22 mục 9: khoá chỉ nằm ở dịch vụ coach-chat, app chỉ gọi dịch vụ đó');
  });

  test('thành tích chỉ sinh ra từ newAchievements', () {
    // Thành tích tạo tay là thành tích "ảo" (spec 2026-10-15 mục 2.7). Ngoài
    // lõi và tầng dữ liệu, không nơi nào được dựng Achievement(.
    // Khớp đúng lời gọi hàm dựng: toRemoteAchievement(...) không phải dựng mới.
    final constructor = RegExp(r'(?<![A-Za-z0-9_$])Achievement\(');
    final offenders = <String>[];
    for (final file in dartFilesIn('lib')) {
      final path = file.path.replaceAll(r'\', '/');
      if (path.endsWith('lib/domain/roadmap/achievements.dart')) continue;
      if (path.endsWith('lib/data/database/roadmap_converters.dart')) continue;
      if (constructor.hasMatch(codeOnly(file.readAsStringSync()))) offenders.add(path);
    }
    expect(offenders, isEmpty,
        reason: 'thành tích phải đi từ một sự kiện dữ liệu thật qua newAchievements');
  });

  test('gợi ý kiểm tra lại hạng không dựng PlayerRank và không đặt warningRank', () {
    // Hạng chỉ đổi và cảnh báo hạng chỉ có qua một bài BU (rank spec Q15).
    final source = codeOnly(File('lib/domain/roadmap/rank_check.dart').readAsStringSync());
    expect(source, isNot(contains('PlayerRank(')));
    expect(source, isNot(contains('warningRank')));
  });
}
