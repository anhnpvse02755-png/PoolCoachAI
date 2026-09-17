import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: PoolCoachApp()));
}

/// Tạm thời ở nhiệm vụ 1. Nhiệm vụ 7 thay bằng bản dùng router thật.
class PoolCoachApp extends StatelessWidget {
  const PoolCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('PoolCoachAI')),
      ),
    );
  }
}
