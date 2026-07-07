import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio/core/services/desktop/desktop_service_registry.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/desktop/bloc/mini_tracker_cubit.dart';
import 'package:worklog_studio/feature/desktop/presentation/components/mini_hoverable_list_item.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class MiniRecentActivitySection extends StatelessWidget {
  final MiniTrackerState state;
  final VoidCallback onEntrySelected;

  const MiniRecentActivitySection({
    super.key,
    required this.state,
    required this.onEntrySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    final recentEntries = state.allEntries.where((e) => !e.isRunning).toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));

    final Map<String, List<TimeEntry>> groupedEntries = {};
    if (state.isRunning && state.activeEntry != null) {
      final key = state.activeEntry!.taskId ?? state.activeEntry!.id;
      groupedEntries[key] = [state.activeEntry!];
    }
    for (final e in recentEntries) {
      final key = e.taskId ?? e.id;
      if (!groupedEntries.containsKey(key)) {
        groupedEntries[key] = [e];
      } else {
        groupedEntries[key]!.add(e);
      }
    }

    final recentGroups = groupedEntries.values.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorsPalette.background.surface,
        borderRadius: theme.radiuses.md.circular,
        border: Border.all(color: const Color(0xFFeaeffd)),
        boxShadow: [theme.shadows.sm],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: theme.spacings.md,
          horizontal: theme.spacings.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'RECENT ACTIVITY',
              trailing: InkWell(
                onTap: () {
                  DesktopServiceRegistry.instance.openMainWindowFromTray(
                    route: 'history',
                  );
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.spacings.xxs,
                    vertical: theme.spacings.xs,
                  ),
                  child: Text(
                    'VIEW ALL',
                    style: theme.commonTextStyles.caption2.copyWith(
                      color: theme.colorsPalette.accent.primary,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: theme.spacings.sm),
            recentGroups.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(theme.spacings.md),
                    child: Text(
                      'No recent activity.',
                      style: theme.commonTextStyles.body.copyWith(
                        color: theme.colorsPalette.text.muted,
                      ),
                    ),
                  )
                : Column(
                    children: recentGroups.map((group) {
                      return _buildEntryItem(
                        context,
                        theme,
                        group.first,
                        count: group.length,
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryItem(
    BuildContext context,
    AppThemeExtension theme,
    TimeEntry entry, {
    int? count,
  }) {
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

    final hasCount = count != null && count > 1;
    final subtitleText =
        hasCount
            ? '${project != null ? '${project.name} • ' : ''}$count entries'
            : project?.name;

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
      trailing:
          isActive
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
      trailingWidget:
          isActive
              ? (_) => const SizedBox.shrink()
              : (isHovered) => PrimaryButton(
                type:
                    isHovered ? ButtonType.primary : ButtonType.ghost,
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
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: theme.commonTextStyles.caption2Bold.copyWith(
            color: theme.colorsPalette.text.secondary2,
            letterSpacing: 1.1,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}
