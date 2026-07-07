import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio/core/services/desktop/desktop_service_registry.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/desktop/bloc/mini_tracker_cubit.dart';
import 'package:worklog_studio/feature/desktop/presentation/components/mini_hoverable_list_item.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class MiniSearchResultsSection extends StatelessWidget {
  final MiniTrackerState state;
  final String query;
  final VoidCallback onEntrySelected;

  const MiniSearchResultsSection({
    super.key,
    required this.state,
    required this.query,
    required this.onEntrySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final queryLower = query.toLowerCase();

    final filteredTasks = state.tasks
        .where((t) => t.title.toLowerCase().contains(queryLower))
        .toList();
    final filteredProjects = state.projects
        .where((p) => p.name.toLowerCase().contains(queryLower))
        .toList();
    final filteredEntries = state.allEntries
        .where((e) => e.comment?.toLowerCase().contains(queryLower) ?? false)
        .toList();

    final hasResults =
        filteredTasks.isNotEmpty ||
        filteredProjects.isNotEmpty ||
        filteredEntries.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasResults)
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: theme.spacings.md,
              horizontal: theme.spacings.md,
            ),
            child: Text(
              'No results',
              style: theme.commonTextStyles.body.copyWith(
                color: theme.colorsPalette.text.muted,
              ),
            ),
          )
        else ...[
          if (filteredTasks.isNotEmpty) ...[
            _SectionHeader(title: 'TASKS'),
            SizedBox(height: theme.spacings.xxs),
            _ResultCard(
              children: filteredTasks.map((task) {
                final project = task.projectId.isNotEmpty
                    ? state.projects.firstWhereOrNull(
                        (p) => p.id == task.projectId,
                      )
                    : null;
                final isActive =
                    state.isRunning && state.activeEntry?.taskId == task.id;
                return _buildTaskItem(context, theme, task, project, isActive);
              }).toList(),
            ),
            SizedBox(height: theme.spacings.md),
          ],
          if (filteredProjects.isNotEmpty) ...[
            _SectionHeader(title: 'PROJECTS'),
            SizedBox(height: theme.spacings.xxs),
            _ResultCard(
              children: filteredProjects
                  .map((p) => _buildProjectItem(context, theme, p))
                  .toList(),
            ),
            SizedBox(height: theme.spacings.md),
          ],
          if (filteredEntries.isNotEmpty) ...[
            _SectionHeader(title: 'RECENT LOGS'),
            SizedBox(height: theme.spacings.xxs),
            _ResultCard(
              children: filteredEntries
                  .map((e) => _buildEntryItem(context, theme, e))
                  .toList(),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildTaskItem(
    BuildContext context,
    AppThemeExtension theme,
    Task task,
    Project? project,
    bool isActive,
  ) {
    void onTap() {
      context.read<MiniTrackerCubit>().startTimer(
        projectId: project?.id,
        taskId: task.id,
      );
      onEntrySelected();
    }

    final initials = BadgeUtils.getTaskInitials(task.title, project?.name ?? '');
    final colors = BadgeUtils.getBadgeColor(task.id);

    return MiniHoverableListItem(
      leading: WsInitialBadge(
        initials: initials,
        backgroundColor: colors.$1,
        textColor: colors.$2,
        size: WsInitialBadgeSize.small,
      ),
      title: task.title,
      subtitle: project?.name,
      trailing: isActive
          ? Container(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacings.md,
                vertical: theme.spacings.lg,
              ),
              child: Icon(
                Icons.radio_button_checked,
                size: 14,
                color: theme.colorsPalette.accent.danger,
              ),
            )
          : const SizedBox.shrink(),
      trailingWidget: isActive
          ? (_) => const SizedBox.shrink()
          : (isHovered) => PrimaryButton(
                type: isHovered ? ButtonType.primary : ButtonType.ghost,
                size: ButtonSize.sm,
                leftIcon: WorklogStudioAssets.vectors.playFilled24Svg,
                onTap: onTap,
              ),
      onTap: onTap,
    );
  }

  Widget _buildProjectItem(
    BuildContext context,
    AppThemeExtension theme,
    Project project,
  ) {
    void onTap() {
      DesktopServiceRegistry.instance.openMainWindowFromTray(
        route: 'projects',
      );
    }

    final initials = BadgeUtils.getProjectInitials(project.name);
    final colors = BadgeUtils.getBadgeColor(project.id);

    return MiniHoverableListItem(
      leading: WsInitialBadge(
        initials: initials,
        backgroundColor: colors.$1,
        textColor: colors.$2,
        size: WsInitialBadgeSize.small,
      ),
      title: project.name,
      trailingWidget: (isHovered) => PrimaryButton(
        type: isHovered ? ButtonType.primary : ButtonType.ghost,
        size: ButtonSize.sm,
        leftIcon: WorklogStudioAssets.vectors.arrowSmallRight24Svg,
        onTap: onTap,
      ),
      onTap: onTap,
    );
  }

  Widget _buildEntryItem(
    BuildContext context,
    AppThemeExtension theme,
    TimeEntry entry,
  ) {
    final task =
        entry.taskId != null
            ? state.tasks.firstWhereOrNull((t) => t.id == entry.taskId)
            : null;
    final project =
        entry.projectId != null
            ? state.projects.firstWhereOrNull((p) => p.id == entry.projectId)
            : null;
    final title = task?.title ?? entry.comment ?? 'No title';
    final isActive = state.isRunning && state.activeEntry?.id == entry.id;
    final subtitleText = project?.name;

    final initials = BadgeUtils.getTaskInitials(title, project?.name ?? '');
    final idForColor = task?.id ?? project?.id ?? entry.id;
    final colors = BadgeUtils.getBadgeColor(idForColor);

    void onTap() {
      context.read<MiniTrackerCubit>().startTimer(
        projectId: project?.id,
        taskId: task?.id,
        comment: entry.comment,
      );
      onEntrySelected();
    }

    return MiniHoverableListItem(
      leading: WsInitialBadge(
        initials: initials,
        backgroundColor: colors.$1,
        textColor: colors.$2,
        size: WsInitialBadgeSize.small,
      ),
      title: title,
      subtitle: subtitleText,
      trailing: isActive
          ? Container(
              padding: EdgeInsets.symmetric(
                vertical: theme.spacings.sm,
                horizontal: theme.spacings.md,
              ),
              child: Icon(
                Icons.radio_button_checked,
                size: 14,
                color: theme.colorsPalette.accent.danger,
              ),
            )
          : const SizedBox.shrink(),
      trailingWidget: isActive
          ? (_) => const SizedBox.shrink()
          : (isHovered) => PrimaryButton(
                type: isHovered ? ButtonType.primary : ButtonType.ghost,
                size: ButtonSize.sm,
                leftIcon: WorklogStudioAssets.vectors.playFilled24Svg,
                onTap: onTap,
              ),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Text(
      title,
      style: theme.commonTextStyles.caption2Bold.copyWith(
        color: theme.colorsPalette.text.secondary2,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final List<Widget> children;

  const _ResultCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorsPalette.background.surface,
        borderRadius: theme.radiuses.md.circular,
        border: Border.all(color: theme.colorsPalette.accent.primaryMuted),
        boxShadow: [theme.shadows.sm],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: theme.spacings.md,
          horizontal: theme.spacings.md,
        ),
        child: Column(children: children),
      ),
    );
  }
}
