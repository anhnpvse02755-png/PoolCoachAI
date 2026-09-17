import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';

/// Màn Huấn luyện viên, mở đè lên shell từ nút tròn ở mọi tab.
///
/// Có Scaffold và AppBar riêng vì nó nằm ngoài shell 5 tab.
class CoachScreen extends StatelessWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Vi.coachTitle)),
      body: const PcEmptyState(
        icon: Icons.chat_bubble_outline,
        title: Vi.coachTitle,
        body: Vi.coachComing,
      ),
    );
  }
}
