import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/history/presentation/components/history_kpi_strip.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_list.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/page_ui_preferences.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

export 'package:worklog_studio/feature/history/presentation/components/time_entry_list.dart'
    show HistoryViewMode;

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final GlobalKey _selectedRowKey = GlobalKey();
  final ValueNotifier<String> _scrollMessage = ValueNotifier<String>('Idle');

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
      drawer.close();
    } else {
      drawer.openTimeEntryEdit(entry);
    }
  }

  void _handleCreateEntry() {
    context.read<DrawerHostController>().openTimeEntryCreate();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
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

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollUpdateNotification) {
          final isNearTop = notification.metrics.pixels <= 50.0;
          final target = isNearTop ? 'Idle' : 'Scrolling...';
          if (_scrollMessage.value != target) _scrollMessage.value = target;
        }
        return false;
      },
      child: Padding(
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
                    PrimaryButton(
                      onTap: () => context
                          .read<PageUiPreferences>()
                          .setHistoryKpiStripVisible(
                            !prefs.historyKpiStripVisible,
                          ),
                      leftIconWidget:
                          const Icon(Icons.insights_rounded, size: 16),
                      type: prefs.historyKpiStripVisible
                          ? ButtonType.secondary
                          : ButtonType.ghost,
                      size: ButtonSize.sm,
                    ),
                    SegmentedToggle<HistoryViewMode>(
                      value: prefs.historyViewMode,
                      onChanged: (mode) => context
                          .read<PageUiPreferences>()
                          .setHistoryViewMode(mode),
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
                      onTap: _handleCreateEntry,
                      title: 'New Entry', // TODO: l10n
                      leftIcon: WorklogStudioAssets.vectors.plus24Svg,
                      size: ButtonSize.sm,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: theme.spacings.lg),
            ValueListenableBuilder<String>(
              valueListenable: _scrollMessage,
              builder: (context, scrollValue, _) {
                return HistoryKpiStrip(
                  resolvedEntries: resolvedEntries,
                  isVisible: prefs.historyKpiStripVisible &&
                      scrollValue != 'Scrolling...',
                );
              },
            ),
            Expanded(
              child: TimeEntryList(
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
                onSortFieldChanged: (field) => context
                    .read<PageUiPreferences>()
                    .setHistorySortField(field),
                onSortDirectionChanged: (direction) => context
                    .read<PageUiPreferences>()
                    .setHistorySortDirection(direction),
                isSortExpanded: isSortExpanded,
                onSortExpandedToggle: () => context
                    .read<PageUiPreferences>()
                    .setHistorySortExpandedOverride(!isSortExpanded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
