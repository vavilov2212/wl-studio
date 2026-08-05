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

  /// Shrinks the gap above the scroll area while the page header is in its
  /// scrolled-down compact state.
  final bool compact;
  final ScrollController? scrollController;

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
    this.compact = false,
    this.scrollController,
  });

  /// Builds the filter bar with its task/project options resolved from
  /// [EntityResolver]; shared by the stacked and compact toolbar layouts.
  Widget _buildConnectedFilterBar({required bool inline}) {
    return Builder(
      builder: (context) {
        final resolver = context.watch<EntityResolver>();
        final taskOptions = resolver.getResolvedTasks().map((t) {
          final colors = BadgeUtils.getBadgeColor(t.id);
          return SelectOption(
            value: t.id,
            label: t.title,
            leading: WsInitialBadge(
              initials: BadgeUtils.getTaskInitials(t.title, t.projectName),
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
          inline: inline,
        );
      },
    );
  }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TableToolbar(
          isFilterExpanded: isFilterExpanded,
          onFilterTap: onFilterExpandedToggle,
          activeFilterCount: filters.activeCount,
          isSortExpanded: isSortExpanded,
          onSortTap: onSortExpandedToggle,
        ),
        if (compact && (isSortExpanded || isFilterExpanded))
          _CompactToolbarRow(
            sortBar: isSortExpanded
                ? HistorySortBar(
                    field: sortField,
                    direction: sortDirection,
                    onFieldChanged: onSortFieldChanged,
                    onDirectionChanged: onSortDirectionChanged,
                    inline: true,
                  )
                : null,
            filterBar: isFilterExpanded
                ? _buildConnectedFilterBar(inline: true)
                : null,
          )
        else ...[
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
            _buildConnectedFilterBar(inline: false),
          ],
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: compact ? theme.spacings.md : theme.spacings.x2l,
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
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
                    rowKeyBuilder: (item) => item.entry.id == selectedEntry?.id
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
                          color: palette.border.primary.withValues(alpha: 0.4),
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
    );
  }
}

/// Right-aligned single row combining the inline sort and filter bars while
/// the page header is compact, separated by a vertical divider. Scrolls
/// horizontally when the window is too narrow for both.
class _CompactToolbarRow extends StatefulWidget {
  final Widget? sortBar;
  final Widget? filterBar;

  const _CompactToolbarRow({this.sortBar, this.filterBar});

  @override
  State<_CompactToolbarRow> createState() => _CompactToolbarRowState();
}

class _CompactToolbarRowState extends State<_CompactToolbarRow> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Align(
      alignment: Alignment.centerRight,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Padding(
            padding: EdgeInsets.only(top: theme.spacings.sm),
            // Bottom-aligned: the filter bar's pills reserve
            // ClearableFilterPill.overlap above their controls, so aligning
            // ends (rather than centers) keeps the sort controls on the
            // same line as the filter controls.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.sortBar != null) widget.sortBar!,
                if (widget.sortBar != null && widget.filterBar != null) ...[
                  SizedBox(width: theme.spacings.sm),
                  Padding(
                    padding: EdgeInsets.only(bottom: theme.spacings.xxs),
                    child: Container(
                      width: 1,
                      height: theme.spacings.xl,
                      color: theme.colorsPalette.border.primary,
                    ),
                  ),
                  SizedBox(width: theme.spacings.sm),
                ],
                if (widget.filterBar != null) widget.filterBar!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
