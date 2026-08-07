import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_actions_cell.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_stack_grouper.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_table.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

/// A table that renders [TimeEntryStack] groups.
///
/// Single-entry stacks are displayed as normal tappable rows.
/// Multi-entry stacks render a collapsible summary row; individual entry rows
/// appear below the summary when expanded.
class HistoryStackTable extends StatefulWidget {
  final List<TimeEntryStack> stacks;
  final TimeEntry? selectedEntry;
  final GlobalKey? selectedRowKey;
  final ValueChanged<TimeEntry> onRowTap;

  const HistoryStackTable({
    super.key,
    required this.stacks,
    required this.selectedEntry,
    this.selectedRowKey,
    required this.onRowTap,
  });

  @override
  State<HistoryStackTable> createState() => _HistoryStackTableState();
}

class _HistoryStackTableState extends State<HistoryStackTable> {
  final Set<String> _expandedIds = {};

  void _toggleStack(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final borderColor = palette.border.primary.withValues(alpha: 0.4);
    final dividerColor = palette.border.primary;
    final columns = getHistoryTableColumns(theme);

    final rows = <Widget>[];
    for (var si = 0; si < widget.stacks.length; si++) {
      final stack = widget.stacks[si];
      final isLast = si == widget.stacks.length - 1;

      if (stack.isSingle) {
        final entry = stack.representative;
        final isSelected = entry.id == widget.selectedEntry?.id;
        rows.add(_HistoryNormalRow(
          key: isSelected ? widget.selectedRowKey : ValueKey(entry.id),
          entry: entry,
          columns: columns,
          isSelected: isSelected,
          onTap: () => widget.onRowTap(entry.entry),
        ));
      } else {
        final isExpanded = _expandedIds.contains(stack.id);
        final containsSelected = widget.selectedEntry != null &&
            stack.entries.any((e) => e.id == widget.selectedEntry!.id);

        rows.add(_HistoryStackSummaryRow(
          key: containsSelected ? widget.selectedRowKey : ValueKey(stack.id),
          stack: stack,
          isExpanded: isExpanded,
          onToggle: () => _toggleStack(stack.id),
        ));

        if (isExpanded) {
          for (final entry in stack.entries) {
            rows.add(Divider(height: 1, thickness: 1, color: dividerColor));
            final isSelected = entry.id == widget.selectedEntry?.id;
            rows.add(_HistoryItemRow(
              key: ValueKey('item-${entry.id}'),
              entry: entry,
              columns: columns,
              isSelected: isSelected,
              onTap: () => widget.onRowTap(entry.entry),
            ));
          }
        }
      }

      if (!isLast) {
        rows.add(Divider(height: 1, thickness: 1, color: dividerColor));
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.background.surface,
        borderRadius: theme.radiuses.md.circular,
        border: Border.all(color: borderColor),
        boxShadow: [theme.shadows.sm],
      ),
      child: ClipRRect(
        borderRadius: theme.radiuses.md.circular,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, columns, borderColor),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    List<WsTableColumn<ResolvedTimeEntry>> columns,
    Color borderColor,
  ) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      decoration: BoxDecoration(
        color: palette.background.surfaceMuted,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacings.lg,
        vertical: theme.spacings.xxs,
      ),
      child: Row(
        children: columns.asMap().entries.map((e) {
          final col = e.value;
          final isLast = e.key == columns.length - 1;
          final cell = Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : theme.spacings.md),
            child: Align(
              alignment: col.alignment,
              child: Text(
                col.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: theme.commonTextStyles.labelSmall.copyWith(
                  color: palette.text.muted,
                ),
              ),
            ),
          );
          if (col.fixedWidth != null) {
            return SizedBox(width: col.fixedWidth, child: cell);
          }
          return Expanded(flex: col.flex, child: cell);
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Normal single-entry row (mirrors WsTable's _WsTableRow)
// ---------------------------------------------------------------------------

class _HistoryNormalRow extends StatefulWidget {
  final ResolvedTimeEntry entry;
  final List<WsTableColumn<ResolvedTimeEntry>> columns;
  final bool isSelected;
  final VoidCallback onTap;

  const _HistoryNormalRow({
    super.key,
    required this.entry,
    required this.columns,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_HistoryNormalRow> createState() => _HistoryNormalRowState();
}

class _HistoryNormalRowState extends State<_HistoryNormalRow> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final bg = widget.isSelected
        ? palette.accent.primary.withValues(alpha: 0.1)
        : _isPressed
            ? palette.background.surfaceMuted
            : _isHovered
                ? palette.background.surfaceMuted.withValues(alpha: 0.5)
                : Colors.transparent;

    return Container(
      color: bg,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _isHovered = v),
          onHighlightChanged: (v) => setState(() => _isPressed = v),
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacings.lg,
              vertical: theme.spacings.lg,
            ),
            child: Row(
              children: widget.columns.asMap().entries.map((e) {
                final col = e.value;
                final isLast = e.key == widget.columns.length - 1;
                final cell = Padding(
                  padding: EdgeInsets.only(
                    right: isLast ? 0 : theme.spacings.md,
                  ),
                  child: Align(
                    alignment: col.alignment,
                    child: col.builder(context, widget.entry, _isHovered),
                  ),
                );
                if (col.fixedWidth != null) {
                  return SizedBox(width: col.fixedWidth, child: cell);
                }
                return Expanded(flex: col.flex, child: cell);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stack summary row - tapping toggles expand/collapse
// Columns match getHistoryTableColumns flex values exactly:
//   flex 4 | flex 3 | flex 8 | flex 2 | flex 2 | fixedWidth 48
// ---------------------------------------------------------------------------

class _HistoryStackSummaryRow extends StatefulWidget {
  final TimeEntryStack stack;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _HistoryStackSummaryRow({
    super.key,
    required this.stack,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<_HistoryStackSummaryRow> createState() =>
      _HistoryStackSummaryRowState();
}

class _HistoryStackSummaryRowState extends State<_HistoryStackSummaryRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final stack = widget.stack;
    final rep = stack.representative;

    final badgeId = rep.task?.id ?? rep.project?.id ?? rep.id;
    final accentColor = BadgeUtils.getBadgeColor(badgeId).$1;
    final stripeColor = rep.task == null && rep.project == null
        ? palette.text.muted
        : accentColor;

    return SizedBox(
      height: 52,
      child: Container(
        color: _isHovered
            ? palette.background.surfaceMuted
            : palette.background.surface,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onToggle,
            onHover: (v) => setState(() => _isHovered = v),
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacings.lg),
              child: Row(
                children: [
                  // Column 0 - Task & Project (flex 4) with chevron prefix
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: EdgeInsets.only(right: theme.spacings.md),
                      child: Row(
                        children: [
                          Icon(
                            widget.isExpanded
                                ? Icons.expand_more_rounded
                                : Icons.chevron_right_rounded,
                            size: 16,
                            color: palette.text.secondary,
                          ),
                          SizedBox(width: theme.spacings.xxs),
                          Container(
                            width: 3,
                            height: 32,
                            decoration: BoxDecoration(
                              color: stripeColor.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(width: theme.spacings.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  rep.taskTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      theme.commonTextStyles.body2Bold.copyWith(
                                    color: palette.text.primary,
                                  ),
                                ),
                                Text(
                                  rep.projectName,
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

                  // Column 1 - Total duration + range (flex 3)
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: EdgeInsets.only(right: theme.spacings.md),
                      child: _StackDurationCell(stack: stack),
                    ),
                  ),

                  // Column 2 - "N sessions" label (flex 8)
                  Expanded(
                    flex: 8,
                    child: Padding(
                      padding: EdgeInsets.only(right: theme.spacings.md),
                      child: Text(
                        '${stack.count} sessions', // TODO: l10n
                        style: theme.commonTextStyles.caption.copyWith(
                          color: palette.text.muted,
                        ),
                      ),
                    ),
                  ),

                  // Column 3 - Efficiency placeholder (flex 2)
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: EdgeInsets.only(right: theme.spacings.md),
                      child: const SizedBox.shrink(),
                    ),
                  ),

                  // Column 4 - Count chip (flex 2)
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: EdgeInsets.only(right: theme.spacings.md),
                      child: _StackCountChip(
                        count: stack.count,
                        isExpanded: widget.isExpanded,
                      ),
                    ),
                  ),

                  // Column 5 - Actions for representative entry (fixedWidth 48)
                  SizedBox(
                    width: 48,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TimeEntryActionsCell(resolvedEntry: rep),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Duration cell for stack summary row: shows total and full time range.
class _StackDurationCell extends StatelessWidget {
  final TimeEntryStack stack;

  const _StackDurationCell({required this.stack});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final isRunning = context.select<TimeTrackerBloc, bool>(
      (bloc) =>
          stack.entries.any((e) => bloc.state.activeEntryOrNull?.id == e.id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        isRunning
            ? LiveDurationText(
                durationBuilder: (now) => stack.totalDuration(now),
                style: theme.commonTextStyles.body2Bold.copyWith(
                  color: palette.accent.primary,
                ),
              )
            : Text(
                DateFormatter.formatDurationHms(
                  stack.totalDuration(DateTime.now()),
                ),
                style: theme.commonTextStyles.body2Bold.copyWith(
                  color: palette.text.primary,
                ),
              ),
        Text(
          DateFormatter.formatTimeRange(stack.startAt, stack.endAt),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.commonTextStyles.caption.copyWith(
            color: palette.text.muted,
          ),
        ),
      ],
    );
  }
}

/// Small count + chevron chip shown in the status column of a summary row.
class _StackCountChip extends StatelessWidget {
  final int count;
  final bool isExpanded;

  const _StackCountChip({required this.count, required this.isExpanded});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacings.sm,
        vertical: theme.spacings.xs,
      ),
      decoration: BoxDecoration(
        color: palette.background.surfaceMuted,
        border: Border.all(color: palette.border.primary),
        borderRadius: theme.radiuses.sm.circular,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: theme.commonTextStyles.captionBold.copyWith(
              color: palette.text.secondary,
            ),
          ),
          SizedBox(width: theme.spacings.xxs),
          Icon(
            isExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 14,
            color: palette.text.secondary,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual item row (inside an expanded stack) - tappable, canvas-tinted
// ---------------------------------------------------------------------------

class _HistoryItemRow extends StatefulWidget {
  final ResolvedTimeEntry entry;
  final List<WsTableColumn<ResolvedTimeEntry>> columns;
  final bool isSelected;
  final VoidCallback onTap;

  const _HistoryItemRow({
    super.key,
    required this.entry,
    required this.columns,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_HistoryItemRow> createState() => _HistoryItemRowState();
}

class _HistoryItemRowState extends State<_HistoryItemRow> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final bg = widget.isSelected
        ? palette.accent.primary.withValues(alpha: 0.07)
        : _isPressed
            ? palette.background.surfaceMuted
            : _isHovered
                ? palette.background.canvas
                : palette.background.canvas.withValues(alpha: 0.6);

    return Container(
      color: bg,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _isHovered = v),
          onHighlightChanged: (v) => setState(() => _isPressed = v),
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.only(
              // Indent to distinguish item rows from top-level rows
              left: theme.spacings.x2l,
              right: theme.spacings.lg,
              top: theme.spacings.md,
              bottom: theme.spacings.md,
            ),
            child: Row(
              children: widget.columns.asMap().entries.map((e) {
                final col = e.value;
                final isLast = e.key == widget.columns.length - 1;
                final cell = Padding(
                  padding: EdgeInsets.only(
                    right: isLast ? 0 : theme.spacings.md,
                  ),
                  child: Align(
                    alignment: col.alignment,
                    child: DefaultTextStyle(
                      style: theme.commonTextStyles.body2.copyWith(
                        color: palette.text.secondary,
                      ),
                      child: col.builder(context, widget.entry, _isHovered),
                    ),
                  ),
                );
                if (col.fixedWidth != null) {
                  return SizedBox(width: col.fixedWidth, child: cell);
                }
                return Expanded(flex: col.flex, child: cell);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
