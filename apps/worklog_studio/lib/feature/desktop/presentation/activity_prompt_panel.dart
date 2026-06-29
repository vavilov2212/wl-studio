import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  String _lastPersistedComment = '';

  @override
  void initState() {
    super.initState();
    _commandSub = context.read<MiniTrackerCubit>().commands.listen(_handleCommand);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _commandSub?.cancel();
    super.dispose();
  }

  void _commit() {
    context.read<MiniTrackerCubit>().updateComment(_commentController.text);
  }

  void _revert() {
    _commentController.text = _lastPersistedComment;
  }

  void _handleCommand(MiniPanelCommand command) {
    if (!mounted) return;
    switch (command) {
      case MiniPanelCommand.focusComment:
        _lastPersistedComment =
            context.read<MiniTrackerCubit>().state.activeEntry?.comment ?? '';
        _commentController.text = _lastPersistedComment;
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

    return Container(
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
            onSubmitted: (_) => _commit(),
          ),
          SizedBox(height: theme.spacings.xs),
          Text(
            'Enter to submit, Esc to dismiss',
            style: theme.commonTextStyles.caption2.copyWith(
              color: theme.colorsPalette.text.muted,
            ),
          ),
        ],
      ),
    );
  }
}
