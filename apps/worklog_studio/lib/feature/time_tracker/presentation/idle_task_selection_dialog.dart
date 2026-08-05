import 'package:flutter/material.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field_controller.dart';
import 'package:worklog_studio/feature/common/presentation/components/project_selector.dart';
import 'package:worklog_studio/feature/common/presentation/components/task_selector.dart';
import 'package:worklog_studio/feature/time_tracker/cubit/idle_flow_cubit.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

/// Modal dialog shown when the user clicks "Log to another task..." in the
/// idle-resolution Win32 popup. Lets the user pick a project, task, and
/// optional comment, then returns an [IdleTaskSelection] on confirm or null
/// on dismiss.
class IdleTaskSelectionDialog extends StatefulWidget {
  const IdleTaskSelectionDialog({super.key});

  @override
  State<IdleTaskSelectionDialog> createState() =>
      _IdleTaskSelectionDialogState();
}

class _IdleTaskSelectionDialogState extends State<IdleTaskSelectionDialog> {
  String? _projectId;
  String? _taskId;
  final _projectController = InlineFieldController();
  final _taskController = InlineFieldController();
  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();

  @override
  void dispose() {
    _projectController.dispose();
    _taskController.dispose();
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _onProjectSelected(String? projectId) {
    setState(() {
      _projectId = projectId;
      // Reset task when project changes.
      if (_taskId != null) {
        _taskId = null;
        _taskController.resetValue();
      }
    });
  }

  void _onTaskSelected(String? taskId) {
    setState(() => _taskId = taskId);
  }

  void _confirm() {
    Navigator.of(context).pop(
      IdleTaskSelection(
        taskId: _taskId,
        projectId: _projectId,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radiuses.lg),
      ),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: EdgeInsets.all(theme.spacings.x2l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Log idle time to a task', // TODO: l10n
                style: theme.commonTextStyles.title,
              ),
              SizedBox(height: theme.spacings.sm),
              Text(
                'Optionally assign a project and task, then confirm.', // TODO: l10n
                style: theme.commonTextStyles.caption.copyWith(
                  color: palette.text.secondary,
                ),
              ),
              SizedBox(height: theme.spacings.x2l),
              ProjectSelector(
                selectedProjectId: _projectId,
                fieldController: _projectController,
                onProjectSelected: _onProjectSelected,
              ),
              SizedBox(height: theme.spacings.md),
              TaskSelector(
                projectId: _projectId,
                selectedTaskId: _taskId,
                fieldController: _taskController,
                onTaskSelected: _onTaskSelected,
              ),
              SizedBox(height: theme.spacings.md),
              PrimaryInput(
                label: 'Comment', // TODO: l10n
                hintText: 'Optional note for this time entry', // TODO: l10n
                controller: _commentController,
                focusNode: _commentFocus,
                onSubmitted: (_) => _confirm(),
              ),
              SizedBox(height: theme.spacings.x2l),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PrimaryButton(
                    title: 'Cancel', // TODO: l10n
                    type: ButtonType.ghost,
                    size: ButtonSize.sm,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: theme.spacings.md),
                  PrimaryButton(
                    title: 'Confirm', // TODO: l10n
                    type: ButtonType.primary,
                    size: ButtonSize.sm,
                    onTap: _confirm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
