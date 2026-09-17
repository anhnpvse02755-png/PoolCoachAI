import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';

class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PcEmptyState(
      icon: Icons.play_circle_outline,
      title: Vi.playTitle,
      body: Vi.playComing,
    );
  }
}
