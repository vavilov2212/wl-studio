import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';
import 'package:worklog_studio/feature/common/utils/date_format_utils.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_actions_cell.dart';
import 'package:worklog_studio/feature/home/presentation/components/dashboard_charts_section.dart';
import 'package:worklog_studio/state/entity_resolver.dart';

const double _recentActivityWideBreakpoint = 700;

class HomePage extends StatefulWidget {
  final String title;
  final VoidCallback onViewAllHistory;
  final ValueChanged<String> onSelectHistoryEntry;
  final VoidCallback onAddTimeEntry;

  const HomePage({
    super.key,
    required this.title,
    required this.onViewAllHistory,
    required this.onSelectHistoryEntry,
    required this.onAddTimeEntry,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(theme.spacings.x2l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardHeader(onAddTimeEntry: widget.onAddTimeEntry),
          SizedBox(height: theme.spacings.lg),
          const DashboardChartsSection(),
          SizedBox(height: theme.spacings.lg),
          _RecentActivitySection(
            onViewAll: widget.onViewAllHistory,
            onSelectEntry: widget.onSelectHistoryEntry,
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final VoidCallback onAddTimeEntry;

  const _DashboardHeader({required this.onAddTimeEntry});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Dashboard', style: theme.commonTextStyles.h3),
        PrimaryButton(
          title: 'Add Time Entry',
          size: ButtonSize.sm,
                    leftIcon: WorklogStudioAssets.vectors.plus24Svg,
          onTap: onAddTimeEntry,
        ),
      ],
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  final VoidCallback onViewAll;
  final ValueChanged<String> onSelectEntry;

  const _RecentActivitySection({
    required this.onViewAll,
    required this.onSelectEntry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Selector<EntityResolver, List<ResolvedTimeEntry>>(
      selector: (context, resolver) => resolver.getResolvedTimeEntries(),
      shouldRebuild: (prev, next) => !const ListEquality().equals(prev, next),
      builder: (context, resolvedEntries, child) {
        // Most recent first; running entries always lead. Intentionally not
        // grouped by date — this is a flat recent-activity feed, not history.
        final recentEntries = (List.of(resolvedEntries)
              ..sort((a, b) {
                if (a.isRunning && !b.isRunning) return -1;
                if (!a.isRunning && b.isRunning) return 1;
                return b.startAt.compareTo(a.startAt);
              }))
            .take(10)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Activity', style: theme.commonTextStyles.h3),
                TextLink(label: 'View All History', onTap: onViewAll),
              ],
            ),
            SizedBox(height: theme.spacings.lg),
            if (recentEntries.isEmpty)
              Text(
                'No recent activity.',
                style: theme.commonTextStyles.body.copyWith(
                  color: palette.text.muted,
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide =
                      constraints.maxWidth >= _recentActivityWideBreakpoint;

                  return WsTable<ResolvedTimeEntry>(
                    data: recentEntries,
                    onRowTap: (item) => onSelectEntry(item.entry.id),
                    columns: isWide
                        ? _fullColumns(theme)
                        : _compactColumns(theme),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  List<WsTableColumn<ResolvedTimeEntry>> _fullColumns(
    AppThemeExtension theme,
  ) {
    return [
      _taskColumn(theme),
      _durationColumn(theme),
      _commentColumn(theme),
      _efficiencyColumn(theme),
      _statusColumn(theme),
      _actionsColumn(),
    ];
  }

  List<WsTableColumn<ResolvedTimeEntry>> _compactColumns(
    AppThemeExtension theme,
  ) {
    return [
      _taskColumn(theme, flex: 4),
      _durationColumn(theme),
      _statusColumn(theme),
    ];
  }

  WsTableColumn<ResolvedTimeEntry> _taskColumn(
    AppThemeExtension theme, {
    int flex = 4,
  }) {
    return WsTableColumn(
      title: 'Task & Project',
      flex: flex,
      builder: (context, item, isHovered) {
        final palette = theme.colorsPalette;
        final id = item.taskId ?? item.projectId ?? item.id;
        final isUnassigned = item.taskId == null && item.projectId == null;
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
    );
  }

  WsTableColumn<ResolvedTimeEntry> _durationColumn(AppThemeExtension theme) {
    return WsTableColumn(
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
                    _formatExactDuration(item.duration(DateTime.now())),
                    style: theme.commonTextStyles.labelMedium.copyWith(
                      color: palette.text.primary,
                    ),
                  ),
            Text(
              isActive
                  ? '${_formatTime(item.startAt)} → now'
                  : DateFormatUtils.formatTimeRangeWithDate(
                      item.startAt,
                      item.endAt,
                    ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.commonTextStyles.caption.copyWith(
                color: palette.text.muted,
              ),
            ),
          ],
        );
      },
    );
  }

  WsTableColumn<ResolvedTimeEntry> _commentColumn(AppThemeExtension theme) {
    return WsTableColumn(
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
    );
  }

  WsTableColumn<ResolvedTimeEntry> _efficiencyColumn(
    AppThemeExtension theme,
  ) {
    return WsTableColumn(
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
            const SizedBox(height: 4),
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
    );
  }

  WsTableColumn<ResolvedTimeEntry> _statusColumn(AppThemeExtension theme) {
    return WsTableColumn(
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
    );
  }

  WsTableColumn<ResolvedTimeEntry> _actionsColumn() {
    return WsTableColumn(
      title: '',
      alignment: Alignment.centerRight,
      fixedWidth: 48,
      builder: (context, item, _) {
        return TimeEntryActionsCell(resolvedEntry: item);
      },
    );
  }

  String _formatExactDuration(Duration duration) {
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
