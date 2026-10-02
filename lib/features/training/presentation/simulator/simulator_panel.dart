import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/features/training/presentation/simulator/info_lines.dart';

/// Phần dưới bàn: nút chỉnh, công tắc bù ném, bảng thông tin, disclaimer.
class SimulatorPanel extends StatelessWidget {
  const SimulatorPanel({
    required this.shot,
    required this.aimed,
    this.cannotSimulate = false,
    required this.advice,
    required this.stroke,
    required this.power,
    required this.spin,
    required this.elevation,
    required this.showUncompensated,
    required this.onStroke,
    required this.onPower,
    required this.onSpin,
    required this.onElevation,
    required this.onShowUncompensated,
    super.key,
  });

  /// Khoá của công tắc *Xem nếu không bù ném*, cho test.
  static const compensateToggleKey = Key('simulator-compensate-toggle');

  /// null khi không lỗ nào đánh được.
  final ShotResult? shot;
  final AimedShot? aimed;

  /// Lõi không mô phỏng được cú này: [aimed] null mà vẫn có cú đánh.
  final bool cannotSimulate;

  /// null khi gợi ý chống chết cái đang tính.
  final List<Advice>? advice;
  final Stroke stroke;
  final double power;
  final SideSpin spin;
  final CueElevation elevation;
  final bool showUncompensated;
  final ValueChanged<Stroke> onStroke;
  final ValueChanged<double> onPower;
  final ValueChanged<SideSpin> onSpin;
  final ValueChanged<CueElevation> onElevation;

  /// null khi công tắc bị khoá (không có ném để xem).
  final ValueChanged<bool>? onShowUncompensated;

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
        chips(Vi.simElevationLabel, CueElevation.values, elevation,
            Vi.simElevation, onElevation),
        SwitchListTile(
          key: compensateToggleKey,
          contentPadding: EdgeInsets.zero,
          title: Text(Vi.simCompensateToggle, style: text.bodyMedium),
          value: showUncompensated,
          onChanged: onShowUncompensated,
        ),
        PcCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in simulatorInfoLines(
                  shot: shot,
                  aimed: aimed,
                  cannotSimulate: cannotSimulate,
                  advice: advice,
                  stroke: stroke,
                  power: power,
                  spin: spin,
                  elevation: elevation,
                ))
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
