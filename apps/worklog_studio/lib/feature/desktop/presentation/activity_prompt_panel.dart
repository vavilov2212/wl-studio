import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/feature/desktop/ipc/ipc_models.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

/// The dedicated "what are you working on" prompt - a single comment text
/// field, shown in its own small floating window (see `ActivityPromptApp`).
/// Opened by the toggle hotkey, the reminder, or a button in `MiniPanel`;
/// Enter (Accept hotkey) commits, Escape (Dismiss hotkey) discards.
///
/// Unlike `MiniPanel`'s inline comment editor, this field is always in
/// "edit mode" by design - there is no view-mode/click-to-edit state here,
/// the whole window exists only to edit the comment. Its text is
/// (re)seeded from the persisted comment each time `MiniPanelCommand.
/// focusComment` arrives (i.e. each time this window is shown), not on
/// every snapshot rebuild, so an in-progress edit is never clobbered by an
/// unrelated snapshot update arriving while the window is open.
class ActivityPromptPanel extends StatefulWidget {
  const ActivityPromptPanel({super.key});

  @override
  State<ActivityPromptPanel> createState() => _ActivityPromptPanelState();
}

class _ActivityPromptPanelState extends State<ActivityPromptPanel> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  StreamSubscription<MiniPanelCommand>? _commandSub;
  StreamSubscription<ActivityPromptStatus>? _statusSub;
  Timer? _countdownTicker;
  ActivityPromptStatus? _status;
  String _lastPersistedComment = '';

  @override
  void initState() {
    super.initState();
    _commandSub = context.read<MiniTrackerCubit>().commands.listen(_handleCommand);
    _statusSub = context.read<MiniTrackerCubit>().activityPromptStatus.listen(_handleStatus);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _commandSub?.cancel();
    _statusSub?.cancel();
    _countdownTicker?.cancel();
    super.dispose();
  }

  void _handleStatus(ActivityPromptStatus status) {
    if (!mounted) return;
    setState(() => _status = status);
    _countdownTicker?.cancel();
    _countdownTicker = status.autoDismissAt == null
        ? null
        : Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() {});
          });
  }

  /// What's currently going on, for the user: a live countdown while a
  /// reminder-opened prompt is still unacknowledged, or a simple "stays
  /// open" message otherwise - whether that's because it was opened
  /// deliberately (hotkey/button) or because a reminder-opened prompt has
  /// already been brought into focus once (see `WindowsDesktopService.
  /// toggleActivityPrompt`).
  String get _statusMessage {
    final autoDismissAt = _status?.autoDismissAt;
    if (autoDismissAt == null) {
      return 'Idle - Enter to save, Esc to cancel';
    }
    final remaining = autoDismissAt.difference(DateTime.now()).inSeconds;
    final seconds = remaining < 0 ? 0 : remaining;
    return 'Closing in ${seconds}s - Enter to save, Esc to cancel';
  }

  void _commit() {
    context.read<MiniTrackerCubit>().updateComment(_commentController.text);
  }

  void _revert() {
    _commentController.text = _lastPersistedComment;
  }

  /// Local Enter while this window has actual OS keyboard focus - asks the
  /// leader to accept, which round-trips back as `MiniPanelCommand.
  /// acceptComment` (committing, see [_handleCommand]) and hides the
  /// window, exactly like the global accept hotkey. Routed through the
  /// leader rather than committing directly here so there's exactly one
  /// code path for "accept", not two that could drift apart.
  void _handleLocalAccept() {
    context.read<MiniTrackerCubit>().requestAcceptComment();
  }

  /// Local Escape counterpart to [_handleLocalAccept].
  void _handleLocalDismiss() {
    context.read<MiniTrackerCubit>().requestDismissComment();
  }

  void _handleCommand(MiniPanelCommand command) {
    if (!mounted) return;
    switch (command) {
      case MiniPanelCommand.focusComment:
        _lastPersistedComment =
            context.read<MiniTrackerCubit>().state.activeEntry?.comment ?? '';
        _commentController.text = _lastPersistedComment;
        // Selected, not just focused: the window may not have OS keyboard
        // focus yet (see WindowsDesktopService.showActivityPrompt) - once
        // the user does bring it forward, typing should immediately
        // replace the existing comment rather than insert into it.
        _commentController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _commentController.text.length,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _commentFocusNode.requestFocus();
        });
      case MiniPanelCommand.acceptComment:
        _commit();
      case MiniPanelCommand.dismissComment:
        _revert();
      case MiniPanelCommand.autoDismissComment:
        // An automatic timeout should not silently discard an in-progress
        // edit the way a user-initiated dismiss does, so commit instead
        // when there is actually an unsaved change.
        if (_commentController.text != _lastPersistedComment) {
          _commit();
        } else {
          _revert();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    // CallbackShortcuts (not onSubmitted) is what makes Enter/Escape work
    // here: a multi-line TextField (maxLines > 1) treats Enter as "insert a
    // newline" by default and never calls onSubmitted at all, and there is
    // no equivalent widget-level callback for Escape. CallbackShortcuts is
    // Flutter's documented mechanism for overriding default key behavior
    // for an entire subtree even when a descendant TextField has focus.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _handleLocalAccept,
        const SingleActivator(LogicalKeyboardKey.escape): _handleLocalDismiss,
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacings.lg,
          vertical: theme.spacings.md,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFf8fafc),
          border: Border.all(color: theme.colorsPalette.border.primary.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _commentController,
              focusNode: _commentFocusNode,
              autofocus: true,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Briefly describe what are you working on',
              ),
            ),
            SizedBox(height: theme.spacings.xs),
            Text(
              _statusMessage,
              style: theme.commonTextStyles.caption2.copyWith(
                color: theme.colorsPalette.text.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
