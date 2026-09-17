import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PcEmptyState(
      icon: Icons.track_changes_outlined,
      title: Vi.trainingTitle,
      body: Vi.trainingComing,
    );
  }
}
