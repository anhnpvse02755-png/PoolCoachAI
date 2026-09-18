import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PcRootScaffold(
      title: Vi.statsTitle,
      body: PcEmptyState(
        icon: Icons.bar_chart_outlined,
        title: Vi.statsTitle,
        body: Vi.statsComing,
      ),
    );
  }
}
