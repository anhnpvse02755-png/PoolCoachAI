import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';

/// Phần dưới bàn: chọn kiểu đánh/lực/áp phê, bảng thông tin, disclaimer.
class SimulatorPanel extends StatelessWidget {
  const SimulatorPanel({
    required this.shot,
    required this.path,
    required this.advice,
    required this.stroke,
    required this.power,
    required this.spin,
    required this.onStroke,
    required this.onPower,
    required this.onSpin,
    super.key,
  });

  /// null khi không lỗ nào đánh được.
  final ShotResult? shot;
  final CueBallPath? path;
  final List<Advice> advice;
  final Stroke stroke;
  final double power;
  final SideSpin spin;
  final ValueChanged<Stroke> onStroke;
  final ValueChanged<double> onPower;
  final ValueChanged<SideSpin> onSpin;

  List<String> _infoLines() {
    final shot = this.shot;
    final path = this.path;
    return switch (shot) {
      null => [Vi.simNoPocket],
      // Không đánh được thì chỉ nói lý do (spec mục 5.4).
      Unmakeable(:final reason) => [Vi.simUnmakeable(reason)],
      Makeable(:final geometry) => [
          Vi.simPocketLine(geometry.pocket),
          Vi.simAngleLine(geometry.angle),
          Vi.simBandLine(bandFor(geometry.angle)),
          Vi.simStrokeLine(stroke),
          Vi.simPowerLine(power),
          Vi.simSpinLine(spin),
          if (path?.scratch case final pocket?) Vi.simScratch(pocket),
          if (path != null && path.bankUsed) Vi.simBankWarning,
          if (!spin.isNone && !(path?.bankUsed ?? false)) Vi.simSpinNoRail,
          if (spin.risksMiscue) Vi.simMiscue,
          ...advice.map(Vi.simAdvice),
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    Widget chips<T>(String label, List<T> values, T selected,
            String Function(T) name, ValueChanged<T> onPick) =>
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.titleSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final v in values)
                    ChoiceChip(
                      label: Text(name(v)),
                      selected: v == selected,
                      onSelected: (_) => onPick(v),
                    ),
                ],
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Vi.simHint, style: text.bodySmall),
        chips(Vi.simStrokeLabel, Stroke.values, stroke, Vi.simStroke, onStroke),
        chips(Vi.simPowerLabel, powerPresets, power, Vi.simPowerPreset, onPower),
        chips(Vi.simSpinLabel, SideSpin.all, spin, Vi.simSpinChip, onSpin),
        const SizedBox(height: 12),
        PcCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in _infoLines())
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(line, style: text.bodyMedium),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(Vi.simDisclaimer, style: text.bodySmall),
      ],
    );
  }
}
