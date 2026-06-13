import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/feature/common/utils/date_format_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/card_row.dart';
import 'package:worklog_studio/feature/common/presentation/interactive_card.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';

class TimeEntryCard extends StatelessWidget {
  final ResolvedTimeEntry resolvedEntry;
  final bool isSelected;
  final VoidCallback onTap;

  const TimeEntryCard({
    super.key,
    required this.resolvedEntry,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return InteractiveCard(
      isSelected: isSelected,
      onTap: onTap,
      child: CardRow(
        columns: [
          CardColumn(
            flex: 3,
            child: Row(
              children: [
                Builder(
                  builder: (context) {
                    final id =
                        resolvedEntry.task?.id ??
                        resolvedEntry.project?.id ??
                        resolvedEntry.id;
                    final colors = BadgeUtils.getBadgeColor(id);
                    return Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.$1.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  },
                ),
                SizedBox(width: theme.spacings.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        resolvedEntry.taskTitle,
                        style: theme.commonTextStyles.labelMedium.copyWith(
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        resolvedEntry.projectName,
                        style: theme.commonTextStyles.caption.copyWith(
                          color: palette.text.muted,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          CardColumn(
            flex: 2,
            alignment: Alignment.centerRight,
            child: Builder(
              builder: (context) {
                final isActive = context.select<TimeTrackerBloc, bool>(
                  (bloc) =>
                      bloc.state.activeEntryOrNull?.id ==
                      resolvedEntry.entry.id,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isActive
                        ? LiveDurationText(
                            durationBuilder: (now) =>
                                resolvedEntry.duration(now),
                            style: theme.commonTextStyles.labelMedium.copyWith(
                              color: palette.accent.primary,
                              fontSize: 14,
                            ),
                          )
                        : Text(
                            _formatDuration(
                              resolvedEntry.duration(DateTime.now()),
                            ),
                            style: theme.commonTextStyles.labelMedium.copyWith(
                              color: palette.text.primary,
                              fontSize: 14,
                            ),
                          ),
                    SizedBox(height: theme.spacings.xxs),
                    Text(
                      DateFormatUtils.formatTimeRangeWithDate(
                        resolvedEntry.startAt,
                        resolvedEntry.endAt,
                      ),
                      style: theme.commonTextStyles.caption.copyWith(
                        color: palette.text.muted,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          CardColumn(
            flex: 3,
            child: Text(
              (resolvedEntry.entry.comment?.isEmpty == null ||
                      resolvedEntry.entry.comment?.isEmpty == true)
                  ? 'No comment'
                  : resolvedEntry.entry.comment!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.commonTextStyles.caption.copyWith(
                color:
                    (resolvedEntry.entry.comment?.isEmpty == null ||
                        resolvedEntry.entry.comment?.isEmpty == true)
                    ? palette.text.muted
                    : palette.text.secondary,
              ),
            ),
          ),
          CardColumn(
            flex: 1,
            alignment: Alignment.centerRight,
            child: Builder(
              builder: (context) {
                final isActive = context.select<TimeTrackerBloc, bool>(
                  (bloc) =>
                      bloc.state.activeEntryOrNull?.id ==
                      resolvedEntry.entry.id,
                );
                return StatusBadge(
                  status: isActive ? BadgeStatus.active : BadgeStatus.logged,
                  label: isActive ? 'Running' : 'Logged',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour == 0
        ? 12
        : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }
}
