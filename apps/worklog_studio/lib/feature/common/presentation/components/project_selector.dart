import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/core/services/app_navigation_controller.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field_controller.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

/// Reusable project picker: InlineField + searchable Select with an
/// inline "create project" action. Shared by the entity drawers.
class ProjectSelector extends StatelessWidget {
  final String? selectedProjectId;
  final InlineFieldController fieldController;

  /// Fired when an existing project is picked or a new one is created.
  final ValueChanged<String?> onProjectSelected;

  /// Shown as the InlineField leading widget when no project is selected.
  final Widget? fallbackLeading;
  final Widget? trailing;

  const ProjectSelector({
    super.key,
    required this.selectedProjectId,
    required this.fieldController,
    required this.onProjectSelected,
    this.fallbackLeading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectTaskState>(
      builder: (context, state, child) {
        final selectedProject = state.projects
            .where((p) => p.id == selectedProjectId)
            .firstOrNull;

        Widget? leadingWidget;
        if (selectedProject != null) {
          final initials = BadgeUtils.getProjectInitials(selectedProject.name);
          final colors = BadgeUtils.getBadgeColor(selectedProject.id);
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
          label: 'Project', // TODO: l10n
          value: selectedProject?.name ?? '',
          placeholder: 'Select Project', // TODO: l10n
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
            value: selectedProjectId,
            placeholder: 'Select Project', // TODO: l10n
            onChanged: (value) {
              onProjectSelected(value);
              fieldController.handleEditorCommit();
            },
            actionBuilder: (context, query, close) {
              final exactMatchExists = state.projects.any(
                (p) => p.name.toLowerCase() == query.toLowerCase(),
              );
              if (exactMatchExists && query.isNotEmpty) {
                return const SizedBox.shrink();
              }

              return SelectCreateAction(
                label: query.isEmpty
                    ? 'Create new project'
                    : 'Create project "$query"', // TODO: l10n
                onTap: () async {
                  final newProject = await state.createProject(
                    query.isEmpty ? 'New project' : query,
                    '',
                  );
                  onProjectSelected(newProject.id);
                  fieldController.handleEditorCommit();
                  close();
                },
              );
            },
            options: state.projects.map((p) {
              final initials = BadgeUtils.getProjectInitials(p.name);
              final colors = BadgeUtils.getBadgeColor(p.id);
              return SelectOption(
                value: p.id,
                label: p.name,
                leading: WsInitialBadge(
                  initials: initials,
                  backgroundColor: colors.$1,
                  textColor: colors.$2,
                  size: WsInitialBadgeSize.small,
                ),
                onAction: () =>
                    context.read<AppNavigationController>().openProject(p.id),
                actionTooltip: 'Open project', // TODO: l10n
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
