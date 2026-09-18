import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';

class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PcRootScaffold(
      title: Vi.playTitle,
      body: PcEmptyState(
        icon: Icons.play_circle_outline,
        title: Vi.playTitle,
        body: Vi.playComing,
      ),
    );
  }
}
