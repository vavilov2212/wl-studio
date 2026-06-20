import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio/domain/resolved_task.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';
import 'package:worklog_studio/feature/common/utils/date_format_utils.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_actions_cell.dart';
import 'package:worklog_studio/state/entity_resolver.dart';

const double _wideBreakpoint = 900;
const double _recentActivityWideBreakpoint = 700;

class HomePage extends StatefulWidget {
  final String title;
  final VoidCallback onViewAllTasks;
  final VoidCallback onViewAllHistory;
  final ValueChanged<String> onSelectHistoryEntry;
  final VoidCallback onAddTimeEntry;
  final ValueChanged<String> onSelectTask;

  const HomePage({
    super.key,
    required this.title,
    required this.onViewAllTasks,
    required this.onViewAllHistory,
    required this.onSelectHistoryEntry,
    required this.onAddTimeEntry,
    required this.onSelectTask,
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= _wideBreakpoint;

              final statsSection = isWide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Expanded(child: _DailyFocusCard()),
                          SizedBox(width: theme.spacings.lg),
                          const Expanded(child: _WeeklyTotalsCard()),
                          SizedBox(width: theme.spacings.lg),
                          Expanded(
                            child: _TopTasksPreviewCard(
                              onViewAll: widget.onViewAllTasks,
                              onSelectTask: widget.onSelectTask,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _DailyFocusCard(),
                        SizedBox(height: theme.spacings.lg),
                        const _WeeklyTotalsCard(),
                        SizedBox(height: theme.spacings.lg),
                        _TopTasksPreviewCard(
                          onViewAll: widget.onViewAllTasks,
                          onSelectTask: widget.onSelectTask,
                        ),
                      ],
                    );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  statsSection,
                  SizedBox(height: theme.spacings.lg),
                  _RecentActivitySection(
                    onViewAll: widget.onViewAllHistory,
                    onSelectEntry: widget.onSelectHistoryEntry,
                  ),
                ],
              );
            },
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

class _DailyFocusCard extends StatelessWidget {
  const _DailyFocusCard();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    // Use granular selectors to minimize rebuilds
    final allEntries = context.select(
      (TimeTrackerBloc bloc) => bloc.state.allEntries,
    );
    final isRunning = context.select(
      (TimeTrackerBloc bloc) => bloc.state.isRunning,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    Duration totalFor(DateTime day) {
      return allEntries
          .where((e) {
            final start = DateTime(
              e.startAt.year,
              e.startAt.month,
              e.startAt.day,
            );
            return start == day;
          })
          .fold<Duration>(
            Duration.zero,
            (prev, entry) => prev + entry.duration(now),
          );
    }

    final todayDuration = totalFor(today);
    final yesterdayDuration = totalFor(yesterday);
    final delta = todayDuration - yesterdayDuration;
    final hasComparison = todayDuration > Duration.zero ||
        yesterdayDuration > Duration.zero;
    final isFlat = delta == Duration.zero;
    final isUp = delta > Duration.zero;
    final deltaColor = isFlat
        ? palette.text.secondary
        : isUp
            ? palette.accent.success
            : palette.accent.danger;

    return BaseCard(
      padding: EdgeInsets.all(theme.spacings.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Daily Focus', style: theme.commonTextStyles.h3),
              if (isRunning) const _ActiveBadge(),
            ],
          ),
          SizedBox(height: theme.spacings.lg),
          Text(_formatDuration(todayDuration), style: theme.commonTextStyles.h2),
          SizedBox(height: theme.spacings.xxs),
          Row(
            children: [
              Text(
                'LOGGED TODAY',
                style: theme.commonTextStyles.caption3Bold.copyWith(
                  color: palette.text.secondary,
                ),
              ),
              if (hasComparison) ...[
                SizedBox(width: theme.spacings.sm),
                Icon(
                  isFlat
                      ? Icons.remove_rounded
                      : isUp
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                  size: 10,
                  color: deltaColor,
                ),
                SizedBox(width: theme.spacings.xxs),
                Text(
                  '${_formatDuration(delta.abs())} vs yesterday',
                  style: theme.commonTextStyles.caption3Bold.copyWith(
                    color: deltaColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return '${hours}h ${minutes}m';
}

class _WeeklyTotalsCard extends StatelessWidget {
  const _WeeklyTotalsCard();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final allEntries = context.select(
      (TimeTrackerBloc bloc) => bloc.state.allEntries,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    final weekTotal = allEntries
        .where((e) {
          final start = DateTime(
            e.startAt.year,
            e.startAt.month,
            e.startAt.day,
          );
          return !start.isBefore(startOfWeek) && !start.isAfter(today);
        })
        .fold<Duration>(
          Duration.zero,
          (prev, entry) => prev + entry.duration(now),
        );

    final daysElapsed = today.weekday;
    final avgDuration = Duration(
      minutes: (weekTotal.inMinutes / daysElapsed).round(),
    );

    return BaseCard(
      padding: EdgeInsets.all(theme.spacings.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This Week', style: theme.commonTextStyles.h3),
          SizedBox(height: theme.spacings.lg),
          Text(_formatDuration(weekTotal), style: theme.commonTextStyles.h2),
          SizedBox(height: theme.spacings.xxs),
          Text(
            'LOGGED SINCE MONDAY',
            style: theme.commonTextStyles.caption3Bold.copyWith(
              color: palette.text.secondary,
            ),
          ),
          SizedBox(height: theme.spacings.md),
          MetricCard(
            label: 'DAILY AVERAGE',
            value: Text(
              _formatDuration(avgDuration),
              style: theme.commonTextStyles.subtitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTasksPreviewCard extends StatelessWidget {
  final VoidCallback onViewAll;
  final ValueChanged<String> onSelectTask;

  const _TopTasksPreviewCard({
    required this.onViewAll,
    required this.onSelectTask,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Selector<EntityResolver, List<ResolvedTask>>(
      selector: (context, resolver) => resolver.getResolvedTasks(),
      shouldRebuild: (prev, next) => !const ListEquality().equals(prev, next),
      builder: (context, topTasks, child) {
        final now = DateTime.now();

        final sortedTasks = List.of(topTasks)
          ..sort((a, b) {
            return b.duration(now).compareTo(a.duration(now));
          });

        final displayTasks = sortedTasks.take(3).toList();

        return BaseCard(
          padding: EdgeInsets.all(theme.spacings.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Top Tasks', style: theme.commonTextStyles.h3),
                  TextLink(label: 'View All', onTap: onViewAll),
                ],
              ),
              SizedBox(height: theme.spacings.lg),
              if (displayTasks.isEmpty)
                Text(
                  'No tasks tracked yet.',
                  style: theme.commonTextStyles.body.copyWith(
                    color: palette.text.muted,
                  ),
                )
              else
                Column(
                  spacing: theme.spacings.xxs,
                  children: displayTasks.map((task) {
                    return _CompactTaskRow(
                      task: task,
                      onTap: () => onSelectTask(task.id),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactTaskRow extends StatelessWidget {
  final ResolvedTask task;
  final VoidCallback onTap;

  const _CompactTaskRow({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final initials = BadgeUtils.getTaskInitials(task.title, task.projectName);
    final colors = BadgeUtils.getBadgeColor(task.id);

    return Material(
      color: Colors.transparent,
      borderRadius: theme.radiuses.sm.circular,
      child: InkWell(
        onTap: onTap,
        borderRadius: theme.radiuses.sm.circular,
        hoverColor: palette.background.surfaceMuted,
        splashColor: palette.background.surfaceMuted,
        highlightColor: palette.background.surfaceMuted,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacings.sm,
            vertical: theme.spacings.sm,
          ),
          child: Row(
            children: [
              WsInitialBadge(
                initials: initials,
                backgroundColor: colors.$1,
                textColor: colors.$2,
                size: WsInitialBadgeSize.small,
              ),
              SizedBox(width: theme.spacings.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.commonTextStyles.labelMedium,
                    ),
                    Text(
                      task.projectName,
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
          ),
        ),
      ),
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

// StatusBadge uses an internal LayoutBuilder to switch between pill/dot
// rendering, which breaks intrinsic-dimension probing (e.g. IntrinsicHeight
// in the stats row above). This is a fixed-size stand-in for that one spot.
class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacings.sm,
        vertical: theme.spacings.xxs,
      ),
      decoration: BoxDecoration(
        color: palette.accent.primaryMuted,
        borderRadius: theme.radiuses.pill.circular,
      ),
      child: Text(
        'ACTIVE',
        maxLines: 1,
        softWrap: false,
        style: theme.commonTextStyles.caption2Bold.copyWith(
          color: palette.accent.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

