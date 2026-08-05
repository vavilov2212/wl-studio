import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/history/bloc/history_bloc.dart';
import 'package:worklog_studio/feature/history/presentation/components/history_kpi_strip.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_list.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

export 'package:worklog_studio/feature/history/presentation/components/time_entry_list.dart'
    show HistoryViewMode;

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _compactDuration = Duration(milliseconds: 200);
  static const _compactCurve = Curves.easeOutCubic;

  final GlobalKey _selectedRowKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isScrolled = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _scrollController.dispose();
    _isScrolled.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: _compactCurve,
    );
  }

  /// Routes mouse-wheel events from anywhere on the page (header, gaps,
  /// blank space) into the entry list. Registered through the
  /// [PointerSignalResolver]: when the cursor is over the list itself the
  /// inner [Scrollable] registers first and wins, so the event is never
  /// applied twice.
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_scrollController.hasClients) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final position = _scrollController.position;
      final target =
          (position.pixels + (resolved as PointerScrollEvent).scrollDelta.dy)
              .clamp(position.minScrollExtent, position.maxScrollExtent);
      if (target != position.pixels) position.jumpTo(target);
    });
  }

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
    final drawer = context.watch<DrawerHostController>();
    final selectedEntry = drawer.kind == DrawerEntityKind.timeEntry
        ? drawer.timeEntry
        : null;

    return BlocBuilder<HistoryBloc, HistoryState>(
      builder: (context, historyState) {
        final isFilterExpanded =
            historyState.filterExpandedOverride ??
            historyState.filters.isActive;
        final isSortExpanded = historyState.sortExpanded;

        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            if (notification is ScrollUpdateNotification) {
              final target = notification.metrics.pixels > 50.0;
              if (_isScrolled.value != target) _isScrolled.value = target;
            }
            return false;
          },
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerSignal: _handlePointerSignal,
            child: ValueListenableBuilder<bool>(
              valueListenable: _isScrolled,
              builder: (context, isScrolled, child) => AnimatedPadding(
                duration: _compactDuration,
                curve: _compactCurve,
                padding: EdgeInsets.fromLTRB(
                  theme.spacings.x2l,
                  isScrolled ? theme.spacings.sm : theme.spacings.x2l,
                  theme.spacings.x2l,
                  theme.spacings.none,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSize(
                      duration: _compactDuration,
                      curve: _compactCurve,
                      alignment: Alignment.topCenter,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: _compactDuration,
                                curve: _compactCurve,
                                // AnimatedDefaultTextStyle replaces the ambient
                                // DefaultTextStyle instead of merging with it,
                                // so the color must be explicit here.
                                style: theme.commonTextStyles.h3.copyWith(
                                  color: theme.colorsPalette.text.primary,
                                  fontSize: isScrolled ? 15 : null,
                                ),
                                child: const Text('Time history'), // TODO: l10n
                              ),
                              SizedBox(width: theme.spacings.sm),
                              AnimatedOpacity(
                                duration: _compactDuration,
                                curve: _compactCurve,
                                opacity: isScrolled ? 1.0 : 0.0,
                                child: IgnorePointer(
                                  ignoring: !isScrolled,
                                  child: PrimaryButton(
                                    onTap: _scrollToTop,
                                    // No explicit Icon size: the button's
                                    // IconTheme sizes it to fit the SizedBox
                                    // it wraps icons in; an oversized icon
                                    // paints past that box and looks shifted.
                                    leftIconWidget: const Icon(
                                      Icons.arrow_upward_rounded,
                                    ),
                                    type: ButtonType.ghost,
                                    size: ButtonSize.xs,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: theme.spacings.lg,
                            children: [
                              PrimaryButton(
                                onTap: () {
                                  final turningOn =
                                      !historyState.kpiStripVisible;
                                  context.read<HistoryBloc>().add(
                                    HistoryKpiStripVisibilityChanged(turningOn),
                                  );
                                  // The strip only renders at the top of the
                                  // list - when enabled from the compact state
                                  // nothing would visibly change, so bring the
                                  // user to where it appears.
                                  if (turningOn && _isScrolled.value) {
                                    _scrollToTop();
                                  }
                                },
                                leftIconWidget: const Icon(
                                  Icons.insights_rounded,
                                ),
                                type: historyState.kpiStripVisible
                                    ? ButtonType.secondary
                                    : ButtonType.ghost,
                                size: isScrolled
                                    ? ButtonSize.xs
                                    : ButtonSize.sm,
                              ),
                              SegmentedToggle<HistoryViewMode>(
                                value: historyState.viewMode,
                                compact: isScrolled,
                                onChanged: (mode) => context
                                    .read<HistoryBloc>()
                                    .add(HistoryViewModeChanged(mode)),
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
                                size: isScrolled
                                    ? ButtonSize.xs
                                    : ButtonSize.sm,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: _compactDuration,
                      curve: _compactCurve,
                      height: isScrolled
                          ? theme.spacings.sm
                          : theme.spacings.lg,
                    ),
                    HistoryKpiStrip(
                      resolvedEntries: resolvedEntries,
                      isVisible: historyState.kpiStripVisible && !isScrolled,
                    ),
                    Expanded(
                      child: TimeEntryList(
                        entries: resolvedEntries,
                        selectedEntry: selectedEntry,
                        selectedRowKey: _selectedRowKey,
                        onEntrySelected: _handleEntrySelected,
                        onCreateEntry: _handleCreateEntry,
                        viewMode: historyState.viewMode,
                        onViewModeChanged: (mode) => context
                            .read<HistoryBloc>()
                            .add(HistoryViewModeChanged(mode)),
                        filters: historyState.filters,
                        onFiltersChanged: (f) => context
                            .read<HistoryBloc>()
                            .add(HistoryFilterChanged(f)),
                        isFilterExpanded: isFilterExpanded,
                        onFilterExpandedToggle: () =>
                            context.read<HistoryBloc>().add(
                              HistoryFilterExpandedOverrideSet(
                                !isFilterExpanded,
                              ),
                            ),
                        sortField: historyState.sortField,
                        sortDirection: historyState.sortDirection,
                        onSortFieldChanged: (field) => context
                            .read<HistoryBloc>()
                            .add(HistorySortFieldChanged(field)),
                        onSortDirectionChanged: (direction) => context
                            .read<HistoryBloc>()
                            .add(HistorySortDirectionChanged(direction)),
                        isSortExpanded: isSortExpanded,
                        onSortExpandedToggle: () => context
                            .read<HistoryBloc>()
                            .add(HistorySortExpandedSet(!isSortExpanded)),
                        compact: isScrolled,
                        scrollController: _scrollController,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
