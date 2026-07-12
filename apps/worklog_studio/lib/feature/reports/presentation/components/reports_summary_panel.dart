import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/reports/reports_aggregator.dart';
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
                      color: slice.id.isEmpty ? palette.text.muted : BadgeUtils.getBadgeColor(slice.id).$2,
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
                          color: slice.id.isEmpty ? palette.text.muted : BadgeUtils.getBadgeColor(slice.id).$2,
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
      ],
    );
  }

  String _formatHours(Duration d) {
    final h = d.inMinutes / 60;
    return '${h.toStringAsFixed(1)}h';
  }
}
