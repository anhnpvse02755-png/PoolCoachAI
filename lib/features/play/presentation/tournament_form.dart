import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/roadmap/pace.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';

/// Hộp thoại thêm hoặc sửa giải; null khi người chơi bỏ qua. [today] là ngày
/// bắt đầu mặc định của giải mới.
Future<TournamentDraft?> showTournamentForm(
  BuildContext context, {
  Tournament? existing,
  required DateTime today,
}) => showDialog<TournamentDraft>(
  context: context,
  builder: (_) => _TournamentFormDialog(existing: existing, today: today),
);

class _TournamentFormDialog extends StatefulWidget {
  const _TournamentFormDialog({required this.existing, required this.today});

  final Tournament? existing;
  final DateTime today;

  @override
  State<_TournamentFormDialog> createState() => _TournamentFormDialogState();
}

class _TournamentFormDialogState extends State<_TournamentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _result;
  late final TextEditingController _notes;
  late DateTime _start;
  DateTime? _end;
  PoolGameType? _gameType;
  var _attempted = false;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _name = TextEditingController(text: t?.name);
    _location = TextEditingController(text: t?.location);
    _result = TextEditingController(text: t?.resultNote);
    _notes = TextEditingController(text: t?.notes);
    _start = dateOnly(t?.startDate ?? widget.today);
    _end = t?.endDate == null ? null : dateOnly(t!.endDate!);
    _gameType = t?.gameType;
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _result.dispose();
    _notes.dispose();
    super.dispose();
  }

  TournamentDraft get _draft => TournamentDraft(
    name: _name.text,
    startDate: _start,
    endDate: _end,
    location: trimmedOrNull(_location.text),
    gameType: _gameType,
    resultNote: trimmedOrNull(_result.text),
    notes: trimmedOrNull(_notes.text),
  );

  /// Lỗi của đúng ô này trong [tournamentInputErrors] của bản nháp hiện tại.
  String? _errorFor(Set<TournamentInputError> own) {
    final hit = tournamentInputErrors(_draft).where(own.contains);
    return hit.isEmpty ? null : Vi.tournamentInputError(hit.first);
  }

  /// Bộ đếm theo ký tự Unicode, cùng đơn vị với [_RuneLimit] và bước kiểm tra
  /// của lõi (mặc định của Flutter đếm theo ký tự hiển thị).
  InputCounterWidgetBuilder _counter(
    TextEditingController controller,
    int max,
  ) =>
      (context, {required currentLength, required isFocused, maxLength}) =>
          Text(
            '${controller.text.runes.length}/$max',
            style: Theme.of(context).textTheme.bodySmall,
          );

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? _start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: Vi.tournamentPickDate,
    );
    if (picked == null || !mounted) return;
    setState(
      () => isStart ? _start = dateOnly(picked) : _end = dateOnly(picked),
    );
  }

  void _save() {
    setState(() => _attempted = true);
    final formOk = _formKey.currentState!.validate();
    if (formOk && tournamentInputErrors(_draft).isEmpty) {
      Navigator.pop<TournamentDraft>(context, _draft);
    }
  }

  Widget _dateRow({
    required Key key,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            key: key,
            onTap: () =>
                _pickDate(isStart: key == const Key('tournament-start')),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: textTheme.bodySmall),
                  Text(value, style: textTheme.bodyLarge),
                ],
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final endBeforeStart = tournamentInputErrors(_draft)
        .contains(TournamentInputError.endBeforeStart);
    return AlertDialog(
      // Máy ngang, bàn phím mở: tiêu đề cuộn cùng ô nhập, chỉ hàng nút đứng yên.
      scrollable: true,
      title: Text(editing ? Vi.tournamentEditTitle : Vi.tournamentAddTitle),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          // Sau lần Lưu hỏng đầu tiên, ô được kiểm lại mỗi khi người dùng gõ,
          // nên lỗi biến mất ngay khi ô hợp lệ thay vì nằm đó tới lần Lưu sau.
          autovalidateMode: _attempted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('tournament-name'),
                controller: _name,
                decoration: const InputDecoration(labelText: Vi.tournamentName),
                inputFormatters: [
                  _RuneLimit(TournamentConstants.nameMaxLength),
                ],
                buildCounter: _counter(
                  _name,
                  TournamentConstants.nameMaxLength,
                ),
                validator: (_) => _errorFor({
                  TournamentInputError.nameRequired,
                  TournamentInputError.nameTooLong,
                }),
              ),
              _dateRow(
                key: const Key('tournament-start'),
                label: Vi.tournamentStartDate,
                value: Vi.shortDate(_start),
              ),
              _dateRow(
                key: const Key('tournament-end'),
                label: Vi.tournamentEndDate,
                value: _end == null
                    ? Vi.tournamentNoEndDate
                    : Vi.shortDate(_end!),
                trailing: _end == null
                    ? null
                    : IconButton(
                        key: const Key('tournament-clear-end'),
                        tooltip: Vi.tournamentClearDate,
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _end = null),
                      ),
              ),
              if (_attempted && endBeforeStart)
                Text(
                  Vi.tournamentInputError(TournamentInputError.endBeforeStart),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              TextFormField(
                key: const Key('tournament-location'),
                controller: _location,
                decoration: const InputDecoration(
                  labelText: Vi.tournamentLocation,
                ),
                inputFormatters: [
                  _RuneLimit(TournamentConstants.locationMaxLength),
                ],
                buildCounter: _counter(
                  _location,
                  TournamentConstants.locationMaxLength,
                ),
                validator: (_) =>
                    _errorFor({TournamentInputError.locationTooLong}),
              ),
              DropdownButtonFormField<PoolGameType?>(
                key: const Key('tournament-game-type'),
                initialValue: _gameType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: Vi.tournamentGameType,
                ),
                items: [
                  const DropdownMenuItem<PoolGameType?>(
                    value: null,
                    child: Text(Vi.tournamentNoGameType),
                  ),
                  for (final type in PoolGameType.values)
                    DropdownMenuItem<PoolGameType?>(
                      value: type,
                      child: Text(Vi.matchGameTypeName(type)),
                    ),
                ],
                onChanged: (v) => setState(() => _gameType = v),
              ),
              TextFormField(
                key: const Key('tournament-result'),
                controller: _result,
                decoration: const InputDecoration(
                  labelText: Vi.tournamentResultNote,
                  helperText: Vi.tournamentResultHint,
                ),
                inputFormatters: [
                  _RuneLimit(TournamentConstants.resultNoteMaxLength),
                ],
                buildCounter: _counter(
                  _result,
                  TournamentConstants.resultNoteMaxLength,
                ),
                validator: (_) =>
                    _errorFor({TournamentInputError.resultNoteTooLong}),
              ),
              TextFormField(
                key: const Key('tournament-notes'),
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: Vi.tournamentNotes,
                ),
                maxLines: 3,
                inputFormatters: [
                  _RuneLimit(TournamentConstants.notesMaxLength),
                ],
                buildCounter: _counter(
                  _notes,
                  TournamentConstants.notesMaxLength,
                ),
                validator: (_) =>
                    _errorFor({TournamentInputError.notesTooLong}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(Vi.cancel),
        ),
        FilledButton(onPressed: _save, child: const Text(Vi.tournamentSave)),
      ],
    );
  }
}

/// Cắt chữ nhập vào ở [max] ký tự Unicode (runes), cùng đơn vị với
/// `tournamentInputErrors`. `maxLength` của Flutter đếm theo ký tự hiển thị nên
/// chữ gõ dấu tổ hợp lọt qua ô nhưng bị bước kiểm tra từ chối.
class _RuneLimit extends TextInputFormatter {
  _RuneLimit(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= max) return newValue;
    final text = String.fromCharCodes(newValue.text.runes.take(max));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
