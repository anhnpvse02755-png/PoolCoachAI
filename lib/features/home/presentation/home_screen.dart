import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PcRootScaffold(
      title: Vi.homeTitle,
      body: PcEmptyState(
        icon: Icons.home_outlined,
        title: Vi.homeTitle,
        body: Vi.homeComing,
      ),
    );
  }
}
