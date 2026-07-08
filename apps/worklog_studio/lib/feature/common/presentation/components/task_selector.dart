import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/core/services/app_navigation_controller.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field_controller.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

/// Reusable task picker: InlineField + searchable Select filtered by
/// [projectId], with an inline "create task" action. Shared by the
/// entity drawers.
class TaskSelector extends StatelessWidget {
  /// Tasks are filtered to this project; inline creation requires it.
  final String? projectId;
  final String? selectedTaskId;
  final InlineFieldController fieldController;

  /// Fired when an existing task is picked or a new one is created.
  final ValueChanged<String?> onTaskSelected;

  /// Shown as the InlineField leading widget when no task is selected.
  final Widget? fallbackLeading;
  final Widget? trailing;

  const TaskSelector({
    super.key,
    required this.projectId,
    required this.selectedTaskId,
    required this.fieldController,
    required this.onTaskSelected,
    this.fallbackLeading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectTaskState>(
      builder: (context, state, child) {
        final selectedTask =
            state.tasks.where((t) => t.id == selectedTaskId).firstOrNull;

        Widget? leadingWidget;
        if (selectedTask != null) {
          final project = state.projects
              .where((p) => p.id == selectedTask.projectId)
              .firstOrNull;
          final initials = BadgeUtils.getTaskInitials(
            selectedTask.title,
            project?.name ?? '',
          );
          final colors = BadgeUtils.getBadgeColor(selectedTask.id);
          leadingWidget = WsInitialBadge(
            initials: initials,
            backgroundColor: colors.$1,
            textColor: colors.$2,
            size: WsInitialBadgeSize.small,
          );
        } else {
          leadingWidget = fallbackLeading;
        }

        return InlineField(
          label: 'Task', // TODO: l10n
          value: selectedTask?.title ?? '',
          placeholder: 'Select Task', // TODO: l10n
          leading: leadingWidget,
          trailing: trailing,
          controller: fieldController,
          editWidget: Select<String>(
            autoOpen: true,
            searchable: true,
            tapRegionGroupId: fieldController.tapRegionGroupId,
            onOpenChange: (isOpen) {
              if (!isOpen) fieldController.handleEditorClose();
            },
            value: selectedTaskId,
            placeholder: 'Select Task', // TODO: l10n
            onChanged: (value) {
              onTaskSelected(value);
              fieldController.handleEditorCommit();
            },
            actionBuilder: (context, query, close) {
              final exactMatchExists = state.tasks.any(
                (t) =>
                    t.title.toLowerCase() == query.toLowerCase() &&
                    t.projectId == projectId,
              );
              if (exactMatchExists && query.isNotEmpty) {
                return const SizedBox.shrink();
              }

              return SelectCreateAction(
                label: query.isEmpty
                    ? 'Create new task'
                    : 'Create task "$query"', // TODO: l10n
                onTap: () async {
                  if (projectId == null) return;
                  final newTask = await state.createTask(
                    projectId!,
                    query.isEmpty ? 'New task' : query,
                    '',
                  );
                  onTaskSelected(newTask.id);
                  fieldController.handleEditorCommit();
                  close();
                },
              );
            },
            options: state.tasks
                .where((t) => t.projectId == projectId)
                .map((t) {
                  final project = state.projects
                      .where((p) => p.id == t.projectId)
                      .firstOrNull;
                  final initials = BadgeUtils.getTaskInitials(
                    t.title,
                    project?.name ?? '',
                  );
                  final colors = BadgeUtils.getBadgeColor(t.id);
                  return SelectOption(
                    value: t.id,
                    label: t.title,
                    leading: WsInitialBadge(
                      initials: initials,
                      backgroundColor: colors.$1,
                      textColor: colors.$2,
                      size: WsInitialBadgeSize.small,
                    ),
                    onAction: () =>
                        context.read<AppNavigationController>().openTask(t.id),
                    actionTooltip: 'Open task', // TODO: l10n
                  );
                })
                .toList(),
          ),
        );
      },
    );
  }
}
