import 'package:flutter/material.dart' hide DrawerControllerState;
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio/feature/common/utils/date_format_utils.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/domain/history_filters.dart';
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
import 'components/history_filter_bar.dart';

enum HistoryViewMode { cards, table }

class HistoryScreen extends StatefulWidget {
  final String? initialSelectedEntryId;
  final int createRequestToken;

  const HistoryScreen({
    super.key,
    this.initialSelectedEntryId,
    this.createRequestToken = 0,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DrawerControllerState<TimeEntry> _drawerState =
      DrawerControllerState.closed();
  HistoryViewMode _viewMode = HistoryViewMode.table;
  HistoryFilters _filters = const HistoryFilters();
  bool? _filterExpandedOverride;
  bool get _isFilterExpanded => _filterExpandedOverride ?? _filters.isActive;
  final GlobalKey _selectedRowKey = GlobalKey();
  late int _handledCreateToken;

  @override
  void initState() {
    super.initState();
    _handledCreateToken = widget.createRequestToken;
    if (widget.initialSelectedEntryId != null) {
      _selectEntryById(widget.initialSelectedEntryId!);
    }
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedEntryId != null &&
        widget.initialSelectedEntryId != oldWidget.initialSelectedEntryId) {
      _selectEntryById(widget.initialSelectedEntryId!);
    }
    if (widget.createRequestToken != _handledCreateToken) {
      _handledCreateToken = widget.createRequestToken;
      _handleCreateEntry();
    }
  }

  void _selectEntryById(String entryId) {
    final resolvedEntry = context
        .read<EntityResolver>()
        .getResolvedTimeEntries()
        .firstWhereOrNull((e) => e.entry.id == entryId);
    if (resolvedEntry != null) {
      setState(() {
        _drawerState = DrawerControllerState.edit(resolvedEntry.entry);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final rowContext = _selectedRowKey.currentContext;
        if (rowContext != null) {
          Scrollable.ensureVisible(
            rowContext,
            duration: const Duration(milliseconds: 300),
            alignment: 0.5,
          );
        }
      });
    }
  }

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
              selectedRowKey: _selectedRowKey,
              onEntrySelected: _handleEntrySelected,
              onCreateEntry: _handleCreateEntry,
              viewMode: _viewMode,
              onViewModeChanged: (mode) => setState(() => _viewMode = mode),
              filters: _filters,
              onFiltersChanged: (f) => setState(() => _filters = f),
              isFilterExpanded: _isFilterExpanded,
              onFilterExpandedToggle: () =>
                  setState(() => _filterExpandedOverride = !_isFilterExpanded),
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
  final GlobalKey? selectedRowKey;
  final ValueChanged<TimeEntry> onEntrySelected;
  final VoidCallback onCreateEntry;
  final HistoryViewMode viewMode;
  final ValueChanged<HistoryViewMode> onViewModeChanged;
  final HistoryFilters filters;
  final ValueChanged<HistoryFilters> onFiltersChanged;
  final bool isFilterExpanded;
  final VoidCallback onFilterExpandedToggle;

  const TimeEntryList({
    super.key,
    required this.entries,
    required this.selectedEntry,
    this.selectedRowKey,
    required this.onEntrySelected,
    required this.onCreateEntry,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.filters,
    required this.onFiltersChanged,
    required this.isFilterExpanded,
    required this.onFilterExpandedToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final filteredEntries = applyHistoryFilters(entries, filters);

    // Sort entries: latest first
    final sortedEntries = List<ResolvedTimeEntry>.from(filteredEntries)
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
                  SegmentedToggle<HistoryViewMode>(
                    value: viewMode,
                    onChanged: onViewModeChanged,
                    options: const [
                      SegmentedToggleOption(
                        value: HistoryViewMode.cards,
                        icon: Icons.view_agenda_rounded,
                      ),
                      SegmentedToggleOption(
                        value: HistoryViewMode.table,
                        icon: Icons.table_rows_rounded,
                      ),
                    ],
                  ),
                  PrimaryButton(
                    onTap: onCreateEntry,
                    title: 'New Entry',
                    leftIcon: WorklogStudioAssets.vectors.plus24Svg,
                    size: ButtonSize.sm,
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
          SizedBox(height: theme.spacings.lg),
          TableToolbar(
            isFilterExpanded: isFilterExpanded,
            onFilterTap: onFilterExpandedToggle,
            activeFilterCount: filters.activeCount,
          ),
          if (isFilterExpanded) ...[
            SizedBox(height: theme.spacings.sm),
            Builder(
              builder: (context) {
                final resolver = context.watch<EntityResolver>();
                final taskOptions = resolver
                    .getResolvedTasks()
                    .map((t) {
                      final colors = BadgeUtils.getBadgeColor(t.id);
                      return SelectOption(
                        value: t.id,
                        label: t.title,
                        leading: WsInitialBadge(
                          initials: BadgeUtils.getTaskInitials(
                            t.title,
                            t.projectName,
                          ),
                          backgroundColor: colors.$1,
                          textColor: colors.$2,
                          size: WsInitialBadgeSize.small,
                        ),
                      );
                    })
                    .toList();
                final projectOptions = resolver
                    .getResolvedProjects()
                    .map((p) {
                      final colors = BadgeUtils.getBadgeColor(p.id);
                      return SelectOption(
                        value: p.id,
                        label: p.name,
                        leading: WsInitialBadge(
                          initials: BadgeUtils.getProjectInitials(p.name),
                          backgroundColor: colors.$1,
                          textColor: colors.$2,
                          size: WsInitialBadgeSize.small,
                        ),
                      );
                    })
                    .toList();
                return HistoryFilterBar(
                  filters: filters,
                  onChanged: onFiltersChanged,
                  taskOptions: taskOptions,
                  projectOptions: projectOptions,
                );
              },
            ),
          ],
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
                                key: isSelected ? selectedRowKey : null,
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
                            rowKeyBuilder: (item) =>
                                item.entry.id == selectedEntry?.id
                                    ? selectedRowKey
                                    : null,
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
        fixedWidth: 48,
        builder: (context, item, isHovered) {
          return TimeEntryActionsCell(
            resolvedEntry: item,
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

