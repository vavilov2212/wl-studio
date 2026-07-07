import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/domain/resolved_task.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/tasks/presentation/components/task_actions_cell.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

List<WsTableColumn<ResolvedTask>> getTaskTableColumns(AppThemeExtension theme) {
  return [
    WsTableColumn(
      title: 'Task & Project',
      flex: 3,
      builder: (context, item, isHovered) {
        final palette = theme.colorsPalette;
        final initials = BadgeUtils.getTaskInitials(
          item.title,
          item.projectName,
        );
        final colors = BadgeUtils.getBadgeColor(item.id);

        return Row(
          children: [
            WsInitialBadge(
              initials: initials,
              backgroundColor: colors.$1,
              textColor: colors.$2,
              size: WsInitialBadgeSize.small,
            ),
            SizedBox(width: theme.spacings.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.commonTextStyles.labelMedium,
                  ),
                  if (item.projectName.isNotEmpty)
                    Text(
                      item.projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.commonTextStyles.caption.copyWith(
                        color: palette.text.secondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
    WsTableColumn(
      title: 'Description',
      flex: 8,
      builder: (context, item, isHovered) {
        final palette = theme.colorsPalette;
        return Text(
          item.task.description.isEmpty
              ? 'No description'
              : item.task.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: theme.commonTextStyles.body2.copyWith(
            color: item.task.description.isEmpty
                ? palette.text.secondary.withValues(alpha: 0.5)
                : palette.text.secondary,
          ),
        );
      },
    ),
    WsTableColumn(
      title: 'Time tracked',
      flex: 2,
      builder: (context, item, isHovered) {
        final isActive = context.select<TimeTrackerBloc, bool>(
          (bloc) => bloc.state.activeEntryOrNull?.taskId == item.id,
        );

        if (isActive) {
          return LiveDurationText(
            durationBuilder: (now) => item.duration(now),
            style: theme.commonTextStyles.labelMedium.copyWith(
              color: theme.colorsPalette.accent.primary,
            ),
          );
        }

        final duration = item.duration(DateTime.now());
        return Text(
          _formatExactDuration(duration),
          style: theme.commonTextStyles.labelMedium,
        );
      },
    ),
    WsTableColumn(
      title: 'Status',
      flex: 1,
      builder: (context, item, isHovered) {
        final isActive = context.select<TimeTrackerBloc, bool>(
          (bloc) => bloc.state.activeEntryOrNull?.taskId == item.id,
        );

        if (isActive) {
          return const Align(
            alignment: Alignment.centerLeft,
            child: StatusBadge(
              status: BadgeStatus.inProgress,
              label: 'RUNNING',
            ),
          );
        }

        return Align(
          alignment: Alignment.centerLeft,
          child: StatusBadge(
            status: _getBadgeStatus(item.status),
            label: item.status.name.toUpperCase(),
          ),
        );
      },
    ),
    WsTableColumn(
      title: 'Actions',
      alignment: Alignment.centerRight,
      flex: 1,
      builder: (context, item, _) {
        return TaskActionsCell(task: item);
      },
    ),
  ];
}

BadgeStatus _getBadgeStatus(TaskStatus status) {
  switch (status) {
    case TaskStatus.open:
      return BadgeStatus.inProgress;
    case TaskStatus.done:
      return BadgeStatus.ready;
    case TaskStatus.archived:
      return BadgeStatus.done;
  }
}

String _formatExactDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
