import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/data/sync/account_actions.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/features/rank/presentation/rank_card.dart';

enum _SignOutChoice { syncFirst, anyway }

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final db = ref.read(appDatabaseProvider);

    final pending = await pendingLogCount(db, userId);
    final pendingRank = await pendingAssessmentCount(db, userId);
    final pendingRoadmap = await pendingRoadmapCount(db, userId);
    final pendingEquipment = await pendingCueEquipmentCount(db, userId);
    final active = await hasActiveTest(db, userId);
    if (pending > 0 ||
        pendingRank > 0 ||
        pendingRoadmap > 0 ||
        pendingEquipment > 0 ||
        active) {
      if (!context.mounted) return;
      final choice = await showDialog<_SignOutChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(Vi.signOutPendingTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pending > 0) Text(Vi.signOutPendingBody(pending)),
              if (pendingRank > 0)
                Text(Vi.signOutPendingAssessment(pendingRank)),
              if (pendingRoadmap > 0)
                Text(Vi.signOutPendingRoadmap(pendingRoadmap)),
              if (pendingEquipment > 0)
                Text(Vi.signOutPendingEquipment(pendingEquipment)),
              if (active) const Text(Vi.signOutActiveTest),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _SignOutChoice.anyway),
              child: const Text(Vi.signOutAnyway),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _SignOutChoice.syncFirst),
              child: const Text(Vi.signOutSyncFirst),
            ),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == _SignOutChoice.syncFirst) {
        await ref.read(syncServiceProvider).syncNow();
        await ref.read(cueEquipmentSyncProvider).syncNow();
        await ref.read(assessmentSyncProvider).syncNow();
        await ref.read(roadmapSyncProvider).syncNow();
        final left = await pendingLogCount(db, userId);
        final leftRank = await pendingAssessmentCount(db, userId);
        final leftRoadmap = await pendingRoadmapCount(db, userId);
        final leftEquipment = await pendingCueEquipmentCount(db, userId);
        if (left > 0 ||
            leftRank > 0 ||
            leftRoadmap > 0 ||
            leftEquipment > 0) {
          // Chỉ còn buổi không bao giờ lên được thì mạng không phải lý do:
          // thử lại mãi cũng vậy, phải chỉ người chơi tới chỗ bỏ chúng.
          final unsyncable = await unsyncableLogCount(db, userId);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                left == unsyncable &&
                        leftRank == 0 &&
                        leftRoadmap == 0 &&
                        leftEquipment == 0
                    ? Vi.syncBlockedByUnsyncable
                    : Vi.syncFailed,
              ),
            ),
          );
          return;
        }
      }
    }

    // Router tự đưa về màn Đăng nhập khi trạng thái đổi.
    await signOutAndForget(
      db: db,
      auth: ref.read(authRepositoryProvider),
      userId: userId,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = switch (ref.watch(authStateProvider)) {
      SignedIn(:final displayName) => displayName,
      SignedOut() => '',
    };

    final unsyncable = ref.watch(unsyncableCountProvider).value ?? 0;

    return PcRootScaffold(
      title: Vi.profileTitle,
      body: Column(
        children: [
          if (unsyncable > 0) _UnsyncableNotice(count: unsyncable),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(Vi.profileSignedInAs(name)),
                const SizedBox(height: AppSpacing.md),
                const RankCard(),
                const SizedBox(height: AppSpacing.lg),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.sports),
                    title: const Text(Vi.equipmentTitle),
                    subtitle: const Text(Vi.equipmentCardBody),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(Routes.equipment),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const TestHistoryList(),
              ],
            ),
          ),
          // Đăng xuất ghim ở đáy: thẻ hạng và lịch sử dài ra thì nút vẫn ở chỗ cũ.
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: OutlinedButton.icon(
              onPressed: () => _signOut(context, ref),
              icon: const Icon(Icons.logout),
              label: const Text(Vi.profileSignOut),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnsyncableNotice extends ConsumerWidget {
  const _UnsyncableNotice({required this.count});

  final int count;

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Vi.unsyncableTitle(count)),
        content: Text(Vi.unsyncableConfirmBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(Vi.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(Vi.unsyncableConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await discardUnsyncableLogs(ref.read(appDatabaseProvider), userId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.all(AppSpacing.md),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_outlined),
        title: Text(Vi.unsyncableTitle(count)),
        subtitle: const Text(Vi.unsyncableBody),
        isThreeLine: true,
        trailing: TextButton(
          onPressed: () => _discard(context, ref),
          child: const Text(Vi.unsyncableDiscard),
        ),
      ),
    );
  }
}
