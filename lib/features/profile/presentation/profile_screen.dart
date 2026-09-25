import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/data/sync/account_actions.dart';
import 'package:poolcoachai/domain/auth.dart';

enum _SignOutChoice { syncFirst, anyway }

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final db = ref.read(appDatabaseProvider);

    final pending = await pendingLogCount(db, userId);
    if (pending > 0) {
      if (!context.mounted) return;
      final choice = await showDialog<_SignOutChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(Vi.signOutPendingTitle),
          content: Text(Vi.signOutPendingBody(pending)),
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
        if (await pendingLogCount(db, userId) > 0) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(Vi.syncFailed)),
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
            child: PcEmptyState(
              icon: Icons.person_outline,
              title: Vi.profileSignedInAs(name),
              body: Vi.profileComing,
              action: OutlinedButton.icon(
                onPressed: () => _signOut(context, ref),
                icon: const Icon(Icons.logout),
                label: const Text(Vi.profileSignOut),
              ),
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
