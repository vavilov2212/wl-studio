import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio/domain/history_filters.dart';
import 'package:worklog_studio/domain/history_sort.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/history/presentation/components/history_filter_bar.dart';
import 'package:worklog_studio/feature/history/presentation/components/history_sort_bar.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_card.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_table.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

enum HistoryViewMode { cards, table }

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
      padding: EdgeInsets.all(theme.spacings.none),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                                    DateFormatter.formatDateHeader(date),
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
                                  DateFormatter.formatDurationHm(totalDuration),
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
                              columns: getHistoryTableColumns(theme),
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
                      columns: getHistoryTableColumns(theme),
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
}
