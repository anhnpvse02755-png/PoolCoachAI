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
    if (yes != true || !mounted) return;
    await ref.read(coachChatControllerProvider.notifier).clear();
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
        // `LayoutBuilder` ở đây để biết chiều cao THẬT còn lại cho cả thân
        // màn (Scaffold đã tự co lại tránh bàn phím) — ô nhập co giãn theo
        // chữ (vẫn `minLines: 1`) nhưng không bao giờ được cao hơn phần
        // dành cho nó; cao hơn thì cuộn ngay bên trong ô, không tràn ra
        // ngoài và không đẩy mất nút Gửi (I4, review Task 10 fix round 1).
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 480.0;
            final inputMaxHeight = (totalHeight * 0.6).clamp(56.0, 220.0).toDouble();
            return Column(
              children: [
                Expanded(child: _buildList(state, turns)),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: inputMaxHeight),
                          child: TextField(
                            key: CoachChatScreen.inputKey,
                            controller: _controller,
                            maxLength: coachChatMaxQuestion,
                            enabled: fieldEnabled,
                            minLines: 1,
                            // `null` (không phải 4 cố định): để chiều cao
                            // thật của ô nhập chỉ bị chặn bởi
                            // `ConstrainedBox` phía trên — tự cuộn bên
                            // trong khi chữ cần nhiều chỗ hơn `inputMaxHeight`
                            // cho phép, thay vì cứ cố xin đủ 4 dòng rồi tràn
                            // màn ở màn ngang + bàn phím + chữ lớn.
                            maxLines: null,
                            decoration: InputDecoration(
                              hintText: Vi.coachChatInputHint,
                              counterText: '',
                              helperText: helperText,
                            ),
                            onSubmitted: canSend ? (_) => _send(trimmed) : null,
                          ),
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(CoachChatState state, List<CoachChatEntry> turns) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth * 0.85;
        final items = <Widget>[];

        // Khoá từng mục bằng danh tính nội dung của nó (id lượt chat,
        // 'pending', 'status'), không để Flutter ghép theo VỊ TRÍ trong
        // danh sách: chèn/xoá mục "đang trả lời"/"pending" ở đầu danh sách
        // đẩy mọi lượt cũ hơn sang vị trí khác, nên nếu không khoá, Flutter
        // tái dùng SemanticsNode của một lượt cũ cho nội dung khác (hay
        // ngược lại) — bong bóng câu trả lời cũ bị đổi số hiệu nút và cờ
        // vùng loa bám nhầm (I2, review Task 10 fix round 1).
        if (state.status == CoachChatStatus.sending) {
          // Khoá (I2) + vùng loa (I3) đặt thẳng trong `_bubble` qua
          // `_thinkingRow` (một Semantics container duy nhất) — bọc thêm
          // một Semantics(container: true) nữa ở ngoài sẽ ra HAI nút biên
          // lồng nhau, trình đọc màn hình đọc "đang trả lời" hai lần (đã
          // thấy khi test vùng loa đỏ lại sau khi M2 đổi dòng này thành
          // bong bóng — bong bóng tự có Semantics container riêng của nó).
          items.add(_thinkingRow(context, maxWidth));
        } else if (state.status == CoachChatStatus.failed) {
          // Cùng vùng loa như "đang trả lời" ở trên — gửi hỏng cũng phải
          // được trình đọc màn hình đọc ra ngay (I3, review Task 10 fix
          // round 1).
          items.add(
            Semantics(
              key: const ValueKey('status'),
              liveRegion: true,
              container: true,
              child: _failedRow(context),
            ),
          );
        }

        if (state.pending != null) {
          items.add(
            _bubble(
              context,
              key: const ValueKey('pending'),
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
              key: ValueKey(turn.id),
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

  // Bong bóng như của huấn luyện viên (M2, review Task 10 fix round 1) —
  // trước đây chỉ là chữ trần, không có hình bong bóng như các lượt khác.
  // Khoá (I2) và vùng loa (I3) đặt thẳng vào ĐÂY — `_bubble` đã tự có một
  // Semantics container riêng của nó; bọc thêm một Semantics container nữa
  // ở `_buildList` sẽ ra hai vùng loa lồng nhau, đọc trùng lặp.
  Widget _thinkingRow(BuildContext context, double maxWidth) => _bubble(
    context,
    key: const ValueKey('status'),
    fromPlayer: false,
    text: Vi.coachChatThinking,
    insufficient: false,
    maxWidth: maxWidth,
    liveRegion: true,
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
    Key? key,
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
      key: key,
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
