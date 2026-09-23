import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/bootstrap.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/data/database/database.dart';

/// Nạp seed lúc khởi động — mục 4.3.1 của thiết kế.
///
/// Quên bước này thì mọi tầng bên dưới vẫn đúng và mọi test khác vẫn
/// xanh, nhưng app chạy thật mở ra với thư viện bài tập rỗng: DB chưa
/// ai ghi gì vào.
void main() {
  test('nạp seed xong thì bài tập đã sẵn sàng cho màn hình đầu tiên',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await loadSeed(container);

    container.listen(drillsProvider, (_, _) {});
    await pumpEventQueue();

    expect(container.read(drillsProvider).value?.length, 10);
  });

  test('main nạp seed xong mới dựng app', () {
    // Không có cách nào chạy main() trong kiểm thử mà không dựng app
    // thật, nên kiểm ngay trên mã: thứ tự hai lời gọi này là cả luật.
    final source = File('lib/main.dart').readAsStringSync();

    final seedAt = source.indexOf('await loadSeed(');
    final runAt = source.indexOf('runApp(');

    expect(seedAt, isNonNegative, reason: 'main phải nạp seed lúc khởi động');
    expect(
      seedAt,
      lessThan(runAt),
      reason: 'nạp seed phải xong trước khi màn hình đầu tiên đọc dữ liệu',
    );
  });
}
