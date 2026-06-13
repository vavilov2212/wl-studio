import 'package:flutter/material.dart' hide DrawerControllerState;
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio/feature/common/utils/date_format_utils.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';
import 'package:worklog_studio/feature/common/presentation/drawer_controller_state.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'components/time_entry_card.dart';
import 'components/time_entry_drawer.dart';
import 'components/time_entry_actions_cell.dart';

enum HistoryViewMode { cards, table }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DrawerControllerState<TimeEntry> _drawerState =
      DrawerControllerState.closed();
  HistoryViewMode _viewMode = HistoryViewMode.table;

  void _handleCreateEntry() {
    setState(() {
      _drawerState = DrawerControllerState.create();
    });
  }

  void _handleEntrySelected(TimeEntry entry) {
    setState(() {
      if (_drawerState.state == DrawerState.edit &&
          _drawerState.entity?.id == entry.id) {
        _drawerState = DrawerControllerState.closed(); // Toggle off
      } else {
        _drawerState = DrawerControllerState.edit(entry);
      }
    });
  }

  void _closePanel() {
    setState(() {
      _drawerState = DrawerControllerState.closed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectTaskState>();
    final resolvedEntries = context
        .watch<EntityResolver>()
        .getResolvedTimeEntries();

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: TimeEntryList(
              entries: resolvedEntries,
              selectedEntry: _drawerState.entity,
              onEntrySelected: _handleEntrySelected,
              onCreateEntry: _handleCreateEntry,
              viewMode: _viewMode,
              onViewModeChanged: (mode) => setState(() => _viewMode = mode),
            ),
          ),
          TimeEntryDrawer(
            resolvedEntry: _drawerState.entity != null
                ? resolvedEntries.firstWhereOrNull(
                    (e) => e.entry.id == _drawerState.entity!.id,
                  )
                : null,
            isOpen: _drawerState.isOpen,
            onClose: _closePanel,
          ),
        ],
      ),
    );
  }
}

class TimeEntryList extends StatelessWidget {
  final List<ResolvedTimeEntry> entries;
  final TimeEntry? selectedEntry;
  final ValueChanged<TimeEntry> onEntrySelected;
  final VoidCallback onCreateEntry;
  final HistoryViewMode viewMode;
  final ValueChanged<HistoryViewMode> onViewModeChanged;

  const TimeEntryList({
    super.key,
    required this.entries,
    required this.selectedEntry,
    required this.onEntrySelected,
    required this.onCreateEntry,
    required this.viewMode,
    required this.onViewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    // Sort entries: latest first
    final sortedEntries = List<ResolvedTimeEntry>.from(entries)
      ..sort((a, b) {
        // Active entries always at the top
        if (a.isRunning && !b.isRunning) return -1;
        if (!a.isRunning && b.isRunning) return 1;
        return b.startAt.compareTo(a.startAt);
      });

    // Group by date
    final Map<DateTime, List<ResolvedTimeEntry>> groupedEntries = {};
    for (final resolvedEntry in sortedEntries) {
      final entry = resolvedEntry.entry;
      final date = DateTime(
        entry.startAt.year,
        entry.startAt.month,
        entry.startAt.day,
      );
      if (!groupedEntries.containsKey(date)) {
        groupedEntries[date] = [];
      }
      groupedEntries[date]!.add(resolvedEntry);
    }

    final sortedDates = groupedEntries.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Padding(
      padding: EdgeInsets.all(theme.spacings.x2l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Time history', style: theme.commonTextStyles.h3),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: theme.spacings.lg,
                children: [
                  _ViewModeToggle(
                    viewMode: viewMode,
                    onChanged: onViewModeChanged,
                  ),
                  PrimaryButton(
                    onTap: onCreateEntry,
                    title: 'New Entry',
                    leftIcon: WorklogStudioAssets.vectors.plus24Svg,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: theme.spacings.lg),
          // KPI strip
          Builder(
            builder: (context) {
              final allEntries = context.select(
                (TimeTrackerBloc bloc) => bloc.state.allEntries,
              );
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final todayEntries = entries.where((e) {
                final d = DateTime(
                  e.startAt.year,
                  e.startAt.month,
                  e.startAt.day,
                );
                return d == today;
              });
              final todayDur = todayEntries.fold<Duration>(
                Duration.zero,
                (p, e) => p + e.entry.duration(now),
              );
              final weekStart = today.subtract(
                Duration(days: today.weekday - 1),
              );
              final weekEntries = entries.where((e) {
                return !e.startAt.isBefore(weekStart);
              });
              final weekDur = weekEntries.fold<Duration>(
                Duration.zero,
                (p, e) => p + e.entry.duration(now),
              );
              final unassigned = entries
                  .where((e) => e.task == null)
                  .length;

              String fmtDur(Duration d) =>
                  '${d.inHours}h ${d.inMinutes.remainder(60)}m';

              return Row(
                children: [
                  _KpiChip(label: 'Today', value: fmtDur(todayDur)),
                  SizedBox(width: theme.spacings.sm),
                  _KpiChip(label: 'This week', value: fmtDur(weekDur)),
                  SizedBox(width: theme.spacings.sm),
                  _KpiChip(
                    label: 'Efficiency',
                    value: '94%',
                    valueColor: palette.accent.success,
                  ),
                  SizedBox(width: theme.spacings.sm),
                  _KpiChip(
                    label: 'Unassigned',
                    value: '$unassigned',
                    valueColor: unassigned > 0
                        ? palette.accent.warning
                        : palette.text.secondary,
                  ),
                ],
              );
            },
          ),
          SizedBox(height: theme.spacings.x2l),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...sortedDates.map((date) {
                    final dailyEntries = groupedEntries[date]!;
                    final totalDuration = dailyEntries.fold<Duration>(
                      Duration.zero,
                      (prev, resolvedEntry) =>
                          prev + resolvedEntry.entry.duration(DateTime.now()),
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            left: theme.spacings.xxs,
                            bottom: theme.spacings.sm,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: theme.spacings.md,
                                  vertical: theme.spacings.xxs,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.background.surface,
                                  border: Border.all(
                                    color: palette.border.primary,
                                  ),
                                  borderRadius:
                                      theme.radiuses.pill.circular,
                                ),
                                child: Text(
                                  _formatDateHeader(date),
                                  style: theme.commonTextStyles.labelSmall
                                      .copyWith(
                                        color: palette.text.primary,
                                      ),
                                ),
                              ),
                              SizedBox(width: theme.spacings.sm),
                              Icon(
                                Icons.history_outlined,
                                color: palette.text.muted,
                                size: 14,
                              ),
                              SizedBox(width: theme.spacings.xxs),
                              Text(
                                _formatDuration(totalDuration),
                                style: theme.commonTextStyles.labelSmall
                                    .copyWith(
                                      color: palette.text.muted,
                                    ),
                              ),
                              SizedBox(width: theme.spacings.sm),
                              Expanded(
                                child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: palette.border.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (viewMode == HistoryViewMode.cards)
                          Column(
                            spacing: theme.spacings.md,
                            children: dailyEntries.map((resolvedEntry) {
                              final entry = resolvedEntry.entry;
                              final isSelected = selectedEntry?.id == entry.id;

                              return TimeEntryCard(
                                resolvedEntry: resolvedEntry,
                                isSelected: isSelected,
                                onTap: () => onEntrySelected(entry),
                              );
                            }).toList(),
                          )
                        else
                          WsTable<ResolvedTimeEntry>(
                            showHeader: true,
                            data: dailyEntries,
                            selectedItem: dailyEntries.firstWhereOrNull(
                              (e) => e.entry.id == selectedEntry?.id,
                            ),
                            onRowTap: (item) => onEntrySelected(item.entry),
                            isSelected: (item, selected) =>
                                item.entry.id == selected?.entry.id,
                            columns: _getTableColumns(theme),
                          ),
                        SizedBox(height: theme.spacings.xl),
                      ],
                    );
                  }),
                  // Footer
                  if (entries.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(top: theme.spacings.lg),
                      padding: EdgeInsets.only(
                        top: theme.spacings.xl,
                        bottom: theme.spacings.lg,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: palette.border.primary.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'View all ${entries.length} sessions'.toUpperCase(),
                        style: theme.commonTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: palette.text.secondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<WsTableColumn<ResolvedTimeEntry>> _getTableColumns(
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
      ),
      WsTableColumn(
        title: 'Comment',
        flex: 3,
        builder: (context, item, isHovered) {
          final palette = theme.colorsPalette;
          final hasComment = item.entry.comment?.isNotEmpty == true;
          return Text(
            hasComment ? item.entry.comment! : 'No comment',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.commonTextStyles.caption.copyWith(
              color: hasComment
                  ? palette.text.secondary
                  : palette.text.muted,
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
        flex: 1,
        builder: (context, item, isHovered) {
          return TimeEntryActionsCell(
            resolvedEntry: item,
            isHovered: isHovered,
          );
        },
      ),
    ];
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

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateString = '${months[date.month - 1]} ${date.day}';

    if (targetDate == today) {
      return 'Today · $dateString';
    } else if (targetDate == yesterday) {
      return 'Yesterday · $dateString';
    }
    return dateString;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
}

class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _KpiChip({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacings.md,
        vertical: theme.spacings.sm,
      ),
      decoration: BoxDecoration(
        color: palette.background.surface,
        border: Border.all(color: palette.border.primary),
        borderRadius: theme.radiuses.md.circular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.commonTextStyles.labelSmall.copyWith(
              color: palette.text.muted,
            ),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: theme.commonTextStyles.captionBold.copyWith(
              color: valueColor ?? palette.text.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewModeToggle extends StatelessWidget {
  final HistoryViewMode viewMode;
  final ValueChanged<HistoryViewMode> onChanged;

  const _ViewModeToggle({required this.viewMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      decoration: BoxDecoration(
        color: palette.background.surfaceMuted,
        borderRadius: theme.radiuses.md.circular,
      ),
      padding: EdgeInsets.all(theme.spacings.xxs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(
            context,
            icon: Icons.view_agenda_rounded,
            isSelected: viewMode == HistoryViewMode.cards,
            onTap: () => onChanged(HistoryViewMode.cards),
          ),
          _buildToggleButton(
            context,
            icon: Icons.table_rows_rounded,
            isSelected: viewMode == HistoryViewMode.table,
            onTap: () => onChanged(HistoryViewMode.table),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(
    BuildContext context, {
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Material(
      color: isSelected ? palette.background.surface : Colors.transparent,
      borderRadius: theme.radiuses.sm.circular,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(theme.spacings.sm),
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(
                    color: palette.border.primary.withValues(alpha: 0.5),
                  )
                : Border.all(color: Colors.transparent),
            borderRadius: theme.radiuses.sm.circular,
            boxShadow: isSelected ? [theme.shadows.sm] : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? palette.text.primary : palette.text.secondary,
          ),
        ),
      ),
    );
  }
}
