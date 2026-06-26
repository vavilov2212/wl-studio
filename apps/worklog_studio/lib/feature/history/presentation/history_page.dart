import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio/feature/common/utils/date_format_utils.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/domain/history_filters.dart';
import 'package:worklog_studio/domain/history_sort.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/page_ui_preferences.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'components/time_entry_card.dart';
import 'components/time_entry_actions_cell.dart';
import 'components/history_filter_bar.dart';
import 'components/history_sort_bar.dart';

enum HistoryViewMode { cards, table }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final GlobalKey _selectedRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final drawer = context.read<DrawerHostController>();
    if (drawer.kind == DrawerEntityKind.timeEntry && drawer.timeEntry != null) {
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

  void _handleEntrySelected(TimeEntry entry) {
    final drawer = context.read<DrawerHostController>();
    if (drawer.kind == DrawerEntityKind.timeEntry &&
        drawer.timeEntry?.id == entry.id) {
      drawer.close(); // Toggle off
    } else {
      drawer.openTimeEntryEdit(entry);
    }
  }

  void _handleCreateEntry() {
    context.read<DrawerHostController>().openTimeEntryCreate();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedEntries = context
        .watch<EntityResolver>()
        .getResolvedTimeEntries();
    final prefs = context.watch<PageUiPreferences>();
    final drawer = context.watch<DrawerHostController>();
    final selectedEntry = drawer.kind == DrawerEntityKind.timeEntry
        ? drawer.timeEntry
        : null;
    final isFilterExpanded =
        prefs.historyFilterExpandedOverride ?? prefs.historyFilters.isActive;
    final isSortExpanded = prefs.historySortExpandedOverride ?? false;

    return TimeEntryList(
      entries: resolvedEntries,
      selectedEntry: selectedEntry,
      selectedRowKey: _selectedRowKey,
      onEntrySelected: _handleEntrySelected,
      onCreateEntry: _handleCreateEntry,
      viewMode: prefs.historyViewMode,
      onViewModeChanged: (mode) =>
          context.read<PageUiPreferences>().setHistoryViewMode(mode),
      filters: prefs.historyFilters,
      onFiltersChanged: (f) =>
          context.read<PageUiPreferences>().setHistoryFilters(f),
      isFilterExpanded: isFilterExpanded,
      onFilterExpandedToggle: () => context
          .read<PageUiPreferences>()
          .setHistoryFilterExpandedOverride(!isFilterExpanded),
      sortField: prefs.historySortField,
      sortDirection: prefs.historySortDirection,
      onSortFieldChanged: (field) =>
          context.read<PageUiPreferences>().setHistorySortField(field),
      onSortDirectionChanged: (direction) =>
          context.read<PageUiPreferences>().setHistorySortDirection(direction),
      isSortExpanded: isSortExpanded,
      onSortExpandedToggle: () => context
          .read<PageUiPreferences>()
          .setHistorySortExpandedOverride(!isSortExpanded),
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
  final HistorySortField sortField;
  final SortDirection sortDirection;
  final ValueChanged<HistorySortField> onSortFieldChanged;
  final ValueChanged<SortDirection> onSortDirectionChanged;
  final bool isSortExpanded;
  final VoidCallback onSortExpandedToggle;

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
    required this.sortField,
    required this.sortDirection,
    required this.onSortFieldChanged,
    required this.onSortDirectionChanged,
    required this.isSortExpanded,
    required this.onSortExpandedToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final filteredEntries = applyHistoryFilters(entries, filters);
    final sortedEntries = applyHistorySort(
      filteredEntries,
      sortField,
      sortDirection,
    );
    final isGroupedByDate = sortField == HistorySortField.date;

    // Group by date (only meaningful when sorted by date; otherwise rendered flat)
    final Map<DateTime, List<ResolvedTimeEntry>> groupedEntries = {};
    if (isGroupedByDate) {
      for (final resolvedEntry in sortedEntries) {
        final entry = resolvedEntry.entry;
        final date = DateTime(
          entry.startAt.year,
          entry.startAt.month,
          entry.startAt.day,
        );
        groupedEntries.putIfAbsent(date, () => []).add(resolvedEntry);
      }
    }

    final sortedDates = isGroupedByDate
        ? (groupedEntries.keys.toList()..sort(
            (a, b) => sortDirection == SortDirection.desc
                ? b.compareTo(a)
                : a.compareTo(b),
          ))
        : <DateTime>[];

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
              final unassigned = entries.where((e) => e.task == null).length;

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
            isSortExpanded: isSortExpanded,
            onSortTap: onSortExpandedToggle,
          ),
          if (isSortExpanded) ...[
            SizedBox(height: theme.spacings.sm),
            HistorySortBar(
              field: sortField,
              direction: sortDirection,
              onFieldChanged: onSortFieldChanged,
              onDirectionChanged: onSortDirectionChanged,
            ),
          ],
          if (isFilterExpanded) ...[
            SizedBox(height: theme.spacings.sm),
            Builder(
              builder: (context) {
                final resolver = context.watch<EntityResolver>();
                final taskOptions = resolver.getResolvedTasks().map((t) {
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
                }).toList();
                final projectOptions = resolver.getResolvedProjects().map((p) {
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
                }).toList();
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
                  if (isGroupedByDate)
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
                                    borderRadius: theme.radiuses.pill.circular,
                                  ),
                                  child: Text(
                                    _formatDateHeader(date),
                                    style: theme.commonTextStyles.labelSmall
                                        .copyWith(color: palette.text.primary),
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
                                      .copyWith(color: palette.text.muted),
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
                                final isSelected =
                                    selectedEntry?.id == entry.id;

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
                    })
                  else if (viewMode == HistoryViewMode.cards)
                    Column(
                      spacing: theme.spacings.md,
                      children: sortedEntries.map((resolvedEntry) {
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
                      data: sortedEntries,
                      selectedItem: sortedEntries.firstWhereOrNull(
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
          return TimeEntryActionsCell(resolvedEntry: item);
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
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

  const _KpiChip({required this.label, required this.value, this.valueColor});

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
