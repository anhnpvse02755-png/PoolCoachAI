import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/coach_chat_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_readable_width.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_context.dart';

/// Màn Hỏi huấn luyện viên: chat tự do, câu trả lời dựa trên số liệu tập
/// luyện trên máy, lịch sử lưu trên máy (Giai đoạn B, Task 10).
class CoachChatScreen extends ConsumerStatefulWidget {
  const CoachChatScreen({super.key});

  static const inputKey = Key('coach-chat-input');
  static const sendKey = Key('coach-chat-send');
  static const clearKey = Key('coach-chat-clear');
  static const retryKey = Key('coach-chat-retry');
  static Key sampleKey(int i) => Key('coach-chat-sample-$i');

  @override
  ConsumerState<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends ConsumerState<CoachChatScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(coachChatControllerProvider.notifier).loadQuota();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  void _send(String question) {
    _controller.clear();
    ref.read(coachChatControllerProvider.notifier).send(question);
  }

  Future<void> _confirmClear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Vi.coachChatClear),
        content: const Text(Vi.coachChatClearBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(Vi.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(Vi.coachChatClearYes),
          ),
        ],
      ),
    );
    if (yes == true) {
      await ref.read(coachChatControllerProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(coachChatControllerProvider);
    final turnsAsync = ref.watch(coachChatTurnsProvider);
    // Không hiện giá trị cũ của `coachChatTurnsProvider` khi nó đang xây
    // lại (vd. đổi tài khoản): `isLoading` phải là false, không chỉ
    // `hasValue` (ruling controller review Task 9).
    final turns = turnsAsync.hasValue && !turnsAsync.isLoading ? turnsAsync.value! : const <CoachChatEntry>[];
    final contextAsync = ref.watch(coachContextProvider);

    final canClear = turns.isNotEmpty && state.status != CoachChatStatus.sending;

    final text = _controller.text;
    final trimmed = text.trim();
    final fieldEnabled =
        state.status != CoachChatStatus.sending && state.remaining != 0 && contextAsync.hasValue;
    final canSend = fieldEnabled && trimmed.isNotEmpty && trimmed.length <= coachChatMaxQuestion;

    final helperText = contextAsync.hasError
        ? Vi.coachChatContextError
        : state.remaining == 0
        ? Vi.coachChatQuotaOut
        : state.remaining != null
        ? Vi.coachChatRemaining(state.remaining!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(Vi.coachChatTitle),
        actions: [
          IconButton(
            key: CoachChatScreen.clearKey,
            tooltip: Vi.coachChatClear,
            icon: const Icon(Icons.delete_outline),
            onPressed: canClear ? _confirmClear : null,
          ),
        ],
      ),
      body: PcReadableWidth(
        child: Column(
          children: [
            Expanded(child: _buildList(state, turns)),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: CoachChatScreen.inputKey,
                      controller: _controller,
                      maxLength: coachChatMaxQuestion,
                      enabled: fieldEnabled,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: Vi.coachChatInputHint,
                        counterText: '',
                        helperText: helperText,
                      ),
                      onSubmitted: canSend ? (_) => _send(trimmed) : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    key: CoachChatScreen.sendKey,
                    tooltip: Vi.coachChatSend,
                    icon: const Icon(Icons.send),
                    onPressed: canSend ? () => _send(trimmed) : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(CoachChatState state, List<CoachChatEntry> turns) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth * 0.85;
        final items = <Widget>[];

        if (state.status == CoachChatStatus.sending) {
          // `liveRegion` trên một Semantics không phải biên (container mặc
          // định false) không gắn được vào nút nào cả — nút con gần nhất có
          // biên riêng (hoặc không có biên nào) sẽ không mang cờ này. Phải
          // tự làm biên (`container: true`) thì "đang trả lời" mới thật sự
          // là vùng loa cho trình đọc màn hình.
          items.add(Semantics(liveRegion: true, container: true, child: _thinkingRow(context)));
        } else if (state.status == CoachChatStatus.failed) {
          items.add(_failedRow(context));
        }

        if (state.pending != null) {
          items.add(
            _bubble(
              context,
              fromPlayer: true,
              text: state.pending!,
              insufficient: false,
              maxWidth: maxWidth,
              liveRegion: true,
            ),
          );
        }

        final reversedTurns = turns.reversed.toList();
        for (var i = 0; i < reversedTurns.length; i++) {
          final turn = reversedTurns[i];
          items.add(
            _bubble(
              context,
              fromPlayer: turn.fromPlayer,
              text: turn.text,
              insufficient: turn.insufficient,
              maxWidth: maxWidth,
              liveRegion: i == 0 && !turn.fromPlayer,
            ),
          );
        }

        if (turns.isEmpty && state.pending == null) {
          items.add(_samplesRow(context));
        }

        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(Vi.coachChatDisclaimer, style: Theme.of(context).textTheme.bodySmall),
          ),
        );

        return ListView(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          children: items,
        );
      },
    );
  }

  Widget _thinkingRow(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(Vi.coachChatThinking, style: Theme.of(context).textTheme.bodySmall),
    ),
  );

  Widget _failedRow(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      children: [
        Text(Vi.coachChatError, style: Theme.of(context).textTheme.bodySmall),
        TextButton(
          key: CoachChatScreen.retryKey,
          onPressed: () => ref.read(coachChatControllerProvider.notifier).retry(),
          child: const Text(Vi.coachChatRetry),
        ),
      ],
    ),
  );

  Widget _samplesRow(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < Vi.coachChatSamples.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OutlinedButton(
              key: CoachChatScreen.sampleKey(i),
              style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
              onPressed: () => _send(Vi.coachChatSamples[i]),
              child: Text(Vi.coachChatSamples[i], textAlign: TextAlign.center),
            ),
          ),
      ],
    ),
  );

  Widget _bubble(
    BuildContext context, {
    required bool fromPlayer,
    required String text,
    required bool insufficient,
    required double maxWidth,
    bool liveRegion = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final background = insufficient
        ? colors.surfaceContainerHighest
        : fromPlayer
        ? colors.primaryContainer
        : colors.secondaryContainer;
    final foreground = insufficient ? colors.onSurfaceVariant : null;
    return Align(
      alignment: fromPlayer ? Alignment.centerRight : Alignment.centerLeft,
      child: Semantics(
        container: true,
        liveRegion: liveRegion,
        label: fromPlayer ? Vi.coachChatFromPlayer : Vi.coachChatFromCoach,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: insufficient
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(Vi.coachChatInsufficient, style: TextStyle(color: foreground)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(Vi.coachChatInsufficientHint, style: TextStyle(color: foreground)),
                    ],
                  )
                : Text(text, style: TextStyle(color: foreground)),
          ),
        ),
      ),
    );
  }
}
