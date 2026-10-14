import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';

/// Nút cao 48 px: bấm được bằng ngón tay khi đang cầm cơ (spec mục 7.3).
const _tall = Size.fromHeight(48);

/// Một lượt thành công / không — thang vị trí và các bài đếm lượt.
class ShotInput extends StatelessWidget {
  const ShotInput({
    required this.drillId,
    required this.onShot,
    this.enabled = true,
    super.key,
  });

  final String drillId;
  final ValueChanged<bool> onShot;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: _tall),
            onPressed: enabled ? () => onShot(true) : null,
            child: Text(Vi.buShotYes(drillId)),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: _tall),
            onPressed: enabled ? () => onShot(false) : null,
            child: Text(Vi.buShotNo(drillId)),
          ),
        ),
      ],
    );
  }
}

/// Số bi của một lượt, giới hạn 0…[max] từ đầu — không nhập sai được.
class CountInput extends StatefulWidget {
  const CountInput({required this.max, required this.onSubmit, this.enabled = true, super.key});

  final int max;
  final ValueChanged<int> onSubmit;
  final bool enabled;

  @override
  State<CountInput> createState() => _CountInputState();
}

class _CountInputState extends State<CountInput> {
  int _n = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: Vi.buCountLess,
              iconSize: 32,
              onPressed: _n > 0 ? () => setState(() => _n--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 96,
              child: Text(
                Vi.buCountOf(_n, widget.max),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: Vi.buCountMore,
              iconSize: 32,
              onPressed: _n < widget.max ? () => setState(() => _n++) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: _tall),
          onPressed: widget.enabled ? () => widget.onSubmit(_n) : null,
          child: const Text(Vi.buCountSubmit),
        ),
      ],
    );
  }
}

/// Năm tiêu chí của một lần phá S10. b–e đòi a, nên khoá khi chưa chọn a.
class BreakInput extends StatefulWidget {
  const BreakInput({required this.onSubmit, this.enabled = true, super.key});

  final ValueChanged<BreakCriteria> onSubmit;
  final bool enabled;

  @override
  State<BreakInput> createState() => _BreakInputState();
}

class _BreakInputState extends State<BreakInput> {
  final _v = List<bool>.filled(5, false);

  void _set(int i, bool value) => setState(() {
        _v[i] = value;
        if (i == 0 && !value) {
          for (var j = 1; j < 5; j++) {
            _v[j] = false;
          }
        }
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 5; i++)
          CheckboxListTile(
            value: _v[i],
            title: Text(Vi.buBreakCriterion(i)),
            onChanged: i == 0 || _v[0] ? (x) => _set(i, x ?? false) : null,
          ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: _tall),
          onPressed: widget.enabled
              ? () => widget.onSubmit(
                  BreakCriteria(a: _v[0], b: _v[1], c: _v[2], d: _v[3], e: _v[4]))
              : null,
          child: const Text(Vi.buBreakSubmit),
        ),
      ],
    );
  }
}
