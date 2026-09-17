import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PcEmptyState(
      icon: Icons.bar_chart_outlined,
      title: Vi.statsTitle,
      body: Vi.statsComing,
    );
  }
}
