import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field_controller.dart';
import 'package:worklog_studio/feature/desktop/bloc/mini_tracker_cubit.dart';
import 'package:worklog_studio/feature/desktop/presentation/components/mini_active_timer_text.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class MiniActiveSessionCard extends StatelessWidget {
  final bool isRunning;
  final TimeEntry? activeEntry;
  final MiniTrackerState state;
  final TextEditingController commentController;
  final InlineFieldController commentFieldController;
  final FocusNode commentFocusNode;

  const MiniActiveSessionCard({
    super.key,
    required this.isRunning,
    required this.activeEntry,
    required this.state,
    required this.commentController,
    required this.commentFieldController,
    required this.commentFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    if (!isRunning || activeEntry == null) {
      return Row(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacings.md),
            child: Text(
              'No active session running.',
              style: theme.commonTextStyles.caption.copyWith(
                color: theme.colorsPalette.text.secondary,
              ),
            ),
          ),
        ],
      );
    }

    if (!commentFieldController.isEditing) {
      final persisted = activeEntry!.comment ?? '';
      if (commentController.text != persisted) {
        commentController.text = persisted;
      }
    }

    final task = activeEntry!.taskId != null
        ? state.tasks.firstWhereOrNull(
            (t) =>
                t.id == activeEntry!.taskId &&
                t.projectId == activeEntry!.projectId,
          )
        : null;
    final project = activeEntry!.projectId != null
        ? state.projects.firstWhereOrNull(
            (p) => p.id == activeEntry!.projectId,
          )
        : null;

    final taskName = task?.title ?? activeEntry!.comment ?? 'Running Task';
    final projectName = project?.name;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorsPalette.background.surface,
        borderRadius: theme.radiuses.md.circular,
        border: Border.all(color: theme.colorsPalette.accent.primaryMuted),
        boxShadow: [theme.shadows.sm],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacings.lg,
          vertical: theme.spacings.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACTIVE SESSION',
              style: theme.commonTextStyles.caption2Bold.copyWith(
                color: theme.colorsPalette.text.secondary2,
                letterSpacing: 1.1,
              ),
            ),
            SizedBox(height: theme.spacings.sm),
            Padding(
              padding: EdgeInsets.all(theme.spacings.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    taskName,
                    style: theme.commonTextStyles.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (projectName != null) ...[
                    SizedBox(height: theme.spacings.xs),
                    Text(
                      projectName,
                      style: theme.commonTextStyles.caption.copyWith(
                        color: theme.colorsPalette.text.secondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: theme.spacings.xl),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      MiniActiveTimerText(
                        entry: activeEntry!,
                        style: theme.commonTextStyles.h2.copyWith(
                          color: theme.colorsPalette.text.primary,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Spacer(),
                      PrimaryButton(
                        type: ButtonType.danger,
                        size: ButtonSize.sm,
                        leftIconWidget: const Icon(Icons.stop_sharp),
                        onTap: () {
                          context.read<MiniTrackerCubit>().stopTimer();
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: theme.spacings.lg),
                  InlineField(
                    label: 'Comment',
                    value: commentController.text,
                    placeholder: 'Add a comment...',
                    controller: commentFieldController,
                    textController: commentController,
                    isTextArea: true,
                    viewModeMaxLines: 2,
                    editWidget: TextArea(
                      label: null,
                      hintText: 'Add a comment...',
                      controller: commentController,
                      focusNode: commentFocusNode,
                      autofocus: true,
                    ),
                  ),
                  SizedBox(height: theme.spacings.sm),
                  PrimaryButton(
                    type: ButtonType.ghost,
                    size: ButtonSize.sm,
                    leftIconWidget:
                        const Icon(Icons.chat_bubble_outline, size: 14),
                    onTap: () {
                      context
                          .read<MiniTrackerCubit>()
                          .requestActivityPrompt();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
