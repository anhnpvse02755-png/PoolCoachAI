import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PcRootScaffold(
      title: Vi.profileTitle,
      body: PcEmptyState(
        icon: Icons.person_outline,
        title: Vi.profileTitle,
        body: Vi.profileComing,
      ),
    );
  }
}
