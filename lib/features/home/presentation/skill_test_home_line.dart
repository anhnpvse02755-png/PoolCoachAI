import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/skill_test_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';

/// Một dòng trên Trang chủ: bài cấp thấp nhất đã sẵn sàng kiểm tra, kèm số bài
/// sẵn sàng còn lại. Ẩn khi đang tải hoặc không có bài nào.
class SkillTestHomeLine extends ConsumerWidget {
  const SkillTestHomeLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(testableDrillsProvider);
    if (async.hasError && !async.isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: PcCard(child: Text(Vi.skillTestDataError)),
      );
    }
    final ready = async.hasValue && !async.isLoading ? async.value : null;
    if (ready == null || ready.isEmpty) return const SizedBox.shrink();

    final first = ready.first;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: PcCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_outlined),
          title: Text(Vi.homeSkillTestReady(first.name, ready.length - 1)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(Routes.skillTest(first.id)),
        ),
      ),
    );
  }
}
