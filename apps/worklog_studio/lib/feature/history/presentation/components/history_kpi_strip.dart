import 'package:flutter/material.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class HistoryKpiStrip extends StatelessWidget {
  final List<ResolvedTimeEntry> resolvedEntries;
  final bool isVisible;

  const HistoryKpiStrip({
    super.key,
    required this.resolvedEntries,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayEntries = resolvedEntries.where((e) {
      final d = DateTime(e.startAt.year, e.startAt.month, e.startAt.day);
      return d == today;
    });
    final todayDur = todayEntries.fold<Duration>(
      Duration.zero,
      (p, e) => p + e.entry.duration(now),
    );

    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEntries = resolvedEntries.where((e) {
      return !e.startAt.isBefore(weekStart);
    });
    final weekDur = weekEntries.fold<Duration>(
      Duration.zero,
      (p, e) => p + e.entry.duration(now),
    );

    final unassigned = resolvedEntries.where((e) => e.task == null).length;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: isVisible
          ? Column(
              key: const ValueKey('kpi_strip'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _KpiChip(
                      label: 'Today', // TODO: l10n
                      value: DateFormatter.formatDurationHm(todayDur),
                    ),
                    SizedBox(width: theme.spacings.sm),
                    _KpiChip(
                      label: 'This week', // TODO: l10n
                      value: DateFormatter.formatDurationHm(weekDur),
                    ),
                    SizedBox(width: theme.spacings.sm),
                    _KpiChip(
                      label: 'Efficiency', // TODO: l10n
                      value: '94%',
                      valueColor: palette.accent.success,
                    ),
                    SizedBox(width: theme.spacings.sm),
                    _KpiChip(
                      label: 'Unassigned', // TODO: l10n
                      value: '$unassigned',
                      valueColor: unassigned > 0
                          ? palette.accent.warning
                          : palette.text.secondary,
                    ),
                  ],
                ),
                SizedBox(height: theme.spacings.lg),
              ],
            )
          : const SizedBox.shrink(),
    );
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
          SizedBox(height: theme.spacings.xs),
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
