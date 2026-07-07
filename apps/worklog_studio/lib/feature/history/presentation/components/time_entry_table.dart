import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_actions_cell.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

List<WsTableColumn<ResolvedTimeEntry>> getHistoryTableColumns(
  AppThemeExtension theme,
) {
  return [
    WsTableColumn(
      title: 'Task & Project',
      flex: 4,
      builder: (context, item, isHovered) {
        final palette = theme.colorsPalette;
        final id = item.task?.id ?? item.project?.id ?? item.id;
        final isUnassigned = item.task == null && item.project == null;
        final colors = BadgeUtils.getBadgeColor(id);
        final stripeColor = isUnassigned ? palette.text.muted : colors.$1;

        return Row(
          children: [
            Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: stripeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: theme.spacings.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.taskTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.commonTextStyles.labelMedium,
                  ),
                  Text(
                    item.projectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.commonTextStyles.caption.copyWith(
                      color: palette.text.muted,
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
      title: 'Duration',
      flex: 3,
      builder: (context, item, isHovered) {
        final palette = theme.colorsPalette;
        final isActive = context.select<TimeTrackerBloc, bool>(
          (bloc) => bloc.state.activeEntryOrNull?.id == item.entry.id,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            isActive
                ? LiveDurationText(
                    durationBuilder: (now) => item.duration(now),
                    style: theme.commonTextStyles.labelMedium.copyWith(
                      color: palette.accent.primary,
                    ),
                  )
                : Text(
                    DateFormatter.formatDurationHms(
                      item.duration(DateTime.now()),
                    ),
                    style: theme.commonTextStyles.labelMedium.copyWith(
                      color: palette.text.primary,
                    ),
                  ),
            Text(
              isActive
                  ? '${DateFormatter.formatTime12h(item.startAt)} → now'
                  : DateFormatter.formatTimeRange(item.startAt, item.endAt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.commonTextStyles.caption.copyWith(
                color: palette.text.muted,
              ),
            ),
          ],
        );
      },
    ),
    WsTableColumn(
      title: 'Comment',
      flex: 8,
      builder: (context, item, isHovered) {
        final palette = theme.colorsPalette;
        final hasComment = item.entry.comment?.isNotEmpty == true;
        return Text(
          hasComment ? item.entry.comment! : 'No comment',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: theme.commonTextStyles.caption.copyWith(
            color: hasComment ? palette.text.secondary : palette.text.muted,
            fontStyle: hasComment ? null : FontStyle.italic,
          ),
        );
      },
    ),
    WsTableColumn(
      title: 'Efficiency',
      flex: 2,
      builder: (context, item, isHovered) {
        final palette = theme.colorsPalette;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '94%',
              style: theme.commonTextStyles.labelMedium.copyWith(
                color: palette.accent.success,
              ),
            ),
            SizedBox(height: theme.spacings.xxs),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: 0.94,
                minHeight: 3,
                backgroundColor: palette.background.surfaceMuted,
                valueColor: AlwaysStoppedAnimation<Color>(
                  palette.accent.success,
                ),
              ),
            ),
          ],
        );
      },
    ),
    WsTableColumn(
      title: 'Status',
      flex: 2,
      builder: (context, item, isHovered) {
        final isActive = context.select<TimeTrackerBloc, bool>(
          (bloc) => bloc.state.activeEntryOrNull?.id == item.entry.id,
        );
        return Align(
          alignment: Alignment.centerLeft,
          child: StatusBadge(
            status: isActive ? BadgeStatus.active : BadgeStatus.logged,
            label: isActive ? 'Running' : 'Logged',
          ),
        );
      },
    ),
    WsTableColumn(
      title: '',
      alignment: Alignment.centerRight,
      fixedWidth: 48,
      builder: (context, item, isHovered) {
        return TimeEntryActionsCell(resolvedEntry: item);
      },
    ),
  ];
}
