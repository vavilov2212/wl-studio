import 'package:flutter/material.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/common/presentation/components/card_row.dart';
import 'package:worklog_studio/feature/common/presentation/interactive_card.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_card.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_stack_grouper.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

/// A card that renders a [TimeEntryStack] with collapsible expand/collapse
/// behaviour when the stack contains more than one entry.
///
/// Collapsed: shows a summary card with shadow strips below suggesting depth.
/// Expanded: shows a summary header card + individual [TimeEntryCard] items
/// connected by a left accent line.
class TimeEntryStackCard extends StatefulWidget {
  final TimeEntryStack stack;
  final TimeEntry? selectedEntry;
  final ValueChanged<TimeEntry> onEntrySelected;

  const TimeEntryStackCard({
    super.key,
    required this.stack,
    required this.selectedEntry,
    required this.onEntrySelected,
  });

  @override
  State<TimeEntryStackCard> createState() => _TimeEntryStackCardState();
}

class _TimeEntryStackCardState extends State<TimeEntryStackCard> {
  bool _isExpanded = false;

  bool get _containsSelected =>
      widget.selectedEntry != null &&
      widget.stack.entries.any((e) => e.id == widget.selectedEntry!.id);

  void _toggle() => setState(() => _isExpanded = !_isExpanded);

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final stack = widget.stack;
    final rep = stack.representative;

    final badgeId = rep.task?.id ?? rep.project?.id ?? rep.id;
    final accentColor = BadgeUtils.getBadgeColor(badgeId).$1;

    final summaryCard = InteractiveCard(
      isSelected: !_isExpanded && _containsSelected,
      onTap: _toggle,
      child: CardRow(
        columns: [
          // Task & Project
          CardColumn(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.9),
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
                        rep.taskTitle,
                        style: theme.commonTextStyles.labelMedium.copyWith(
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        rep.projectName,
                        style: theme.commonTextStyles.caption.copyWith(
                          color: palette.text.muted,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Session count label
          CardColumn(
            flex: 3,
            child: Text(
              '${stack.count} sessions', // TODO: l10n
              style: theme.commonTextStyles.caption.copyWith(
                color: palette.text.muted,
              ),
            ),
          ),

          // Total duration + time range
          CardColumn(
            flex: 2,
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormatter.formatDurationHms(
                    stack.totalDuration(DateTime.now()),
                  ),
                  style: theme.commonTextStyles.labelMedium.copyWith(
                    color: palette.text.primary,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: theme.spacings.xxs),
                Text(
                  DateFormatter.formatTimeRange(stack.startAt, stack.endAt),
                  style: theme.commonTextStyles.caption.copyWith(
                    color: palette.text.muted,
                  ),
                ),
              ],
            ),
          ),

          // Expand/collapse chip
          CardColumn(
            flex: 1,
            alignment: Alignment.centerRight,
            child: _ExpandChip(
              count: stack.count,
              isExpanded: _isExpanded,
            ),
          ),
        ],
      ),
    );

    if (!_isExpanded) {
      return _CollapsedStack(
        stack: stack,
        summaryCard: summaryCard,
        accentColor: accentColor,
      );
    }

    // Expanded layout: summary header + individual entry cards with accent line
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        summaryCard,
        SizedBox(height: theme.spacings.sm),
        ...stack.entries.asMap().entries.map((e) {
          final idx = e.key;
          final resolvedEntry = e.value;
          final isLast = idx == stack.entries.length - 1;
          final isSelected = widget.selectedEntry?.id == resolvedEntry.id;

          return Padding(
            padding: EdgeInsets.only(
              bottom: isLast ? 0 : theme.spacings.sm,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Accent connector line
                  Container(
                    width: 2,
                    margin: EdgeInsets.only(
                      left: theme.spacings.lg,
                      right: theme.spacings.sm,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  Expanded(
                    child: TimeEntryCard(
                      key: ValueKey(resolvedEntry.id),
                      resolvedEntry: resolvedEntry,
                      isSelected: isSelected,
                      onTap: () =>
                          widget.onEntrySelected(resolvedEntry.entry),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// The collapsed stack view: summary card + shadow strips underneath that
/// suggest multiple cards stacked behind the main one.
class _CollapsedStack extends StatelessWidget {
  final TimeEntryStack stack;
  final Widget summaryCard;
  final Color accentColor;

  const _CollapsedStack({
    required this.stack,
    required this.summaryCard,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        summaryCard,
        SizedBox(height: theme.spacings.xs),
        // Strip 1 - slightly inset, same surface color
        Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacings.sm),
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: palette.background.surface,
              border: Border.all(
                color: palette.border.primary.withValues(alpha: 0.7),
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(theme.radiuses.md),
                bottomRight: Radius.circular(theme.radiuses.md),
              ),
              boxShadow: [theme.shadows.sm],
            ),
          ),
        ),
        if (stack.count > 2) ...[
          SizedBox(height: theme.spacings.xs),
          // Strip 2 - more inset, muted surface color
          Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.spacings.lg),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: palette.background.surfaceMuted,
                border: Border.all(
                  color: palette.border.primary.withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(theme.radiuses.md),
                  bottomRight: Radius.circular(theme.radiuses.md),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A small pill showing the entry count and a chevron icon.
class _ExpandChip extends StatelessWidget {
  final int count;
  final bool isExpanded;

  const _ExpandChip({required this.count, required this.isExpanded});

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
            style: theme.commonTextStyles.caption.copyWith(
              color: palette.text.secondary,
              fontWeight: FontWeight.w600,
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
