import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/reports/reports_aggregator.dart';
import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class ReportsSummaryPanel extends StatelessWidget {
  final ReportsData data;

  const ReportsSummaryPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Total hours column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total hours', // TODO: l10n
                  style: theme.commonTextStyles.caption.copyWith(
                    color: palette.text.secondary,
                  ),
                ),
                SizedBox(height: theme.spacings.xxs),
                Text(
                  DateFormatter.formatDurationHm(data.totalDuration),
                  style: theme.commonTextStyles.displayLarge.copyWith(
                    color: palette.text.primary,
                  ),
                ),
              ],
            ),
            SizedBox(width: theme.spacings.xl),
            // Donut chart
            SizedBox(
              width: 180,
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: data.byProject.map((slice) {
                    return PieChartSectionData(
                      value: slice.duration.inMinutes.toDouble(),
                      color: _colorFor(slice.id, palette),
                      showTitle: false,
                      radius: 40,
                    );
                  }).toList(),
                  centerSpaceRadius: 45,
                  sectionsSpace: 2,
                ),
              ),
            ),
            SizedBox(width: theme.spacings.lg),
            // Legend
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: data.byProject.map((slice) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: theme.spacings.xxs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _colorFor(slice.id, palette),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: theme.spacings.sm),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          slice.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.commonTextStyles.caption.copyWith(
                            color: palette.text.primary,
                          ),
                        ),
                      ),
                      SizedBox(width: theme.spacings.sm),
                      Text(
                        '${_formatHours(slice.duration)} '
                        '(${(slice.percentOfTotal * 100).round()}%)',
                        style: theme.commonTextStyles.caption.copyWith(
                          color: palette.text.muted,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        SizedBox(height: theme.spacings.lg),
        _BreakdownBar(slices: data.byProject),
      ],
    );
  }

  Color _colorFor(String projectId, ColorsPalette palette) {
    if (projectId.isEmpty) return palette.text.muted;
    return BadgeUtils.getBadgeColor(projectId).$2;
  }

  String _formatHours(Duration d) {
    final h = d.inMinutes / 60;
    return '${h.toStringAsFixed(1)}h';
  }
}

class _BreakdownBar extends StatelessWidget {
  final List<ReportSlice> slices;

  const _BreakdownBar({required this.slices});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final visible = slices.where((s) => s.duration.inMinutes > 0).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 12,
      child: Row(
        children: List.generate(visible.length, (i) {
          final slice = visible[i];
          final isFirst = i == 0;
          final isLast = i == visible.length - 1;
          final radius = theme.radiuses.pill;
          return Flexible(
            flex: (slice.percentOfTotal * 1000).round().clamp(1, 1000),
            child: Container(
              decoration: BoxDecoration(
                color: slice.id.isEmpty
                    ? palette.text.muted
                    : BadgeUtils.getBadgeColor(slice.id).$2,
                borderRadius: BorderRadius.only(
                  topLeft: isFirst ? Radius.circular(radius) : Radius.zero,
                  bottomLeft: isFirst ? Radius.circular(radius) : Radius.zero,
                  topRight: isLast ? Radius.circular(radius) : Radius.zero,
                  bottomRight: isLast ? Radius.circular(radius) : Radius.zero,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
