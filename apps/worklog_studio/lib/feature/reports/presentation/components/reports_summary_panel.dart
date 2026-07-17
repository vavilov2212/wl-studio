import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio/feature/common/presentation/components/stacked_bar_chart.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';
import 'package:worklog_studio/feature/reports/reports_aggregator.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

const double _wideBreakpoint = 900;

// Legend rows shown next to a donut before the rest collapses into a
// "+N more" tooltip row.
const int _maxLegendRows = 6;

String _formatHours(Duration duration) {
  final hours = duration.inMinutes / 60;
  return '${hours.toStringAsFixed(1)}h';
}

class ReportsSummaryPanel extends StatelessWidget {
  final ReportsData data;
  final DashboardChartView view;
  final DashboardPeriod period;
  final ValueChanged<DashboardChartView> onViewChanged;

  const ReportsSummaryPanel({
    super.key,
    required this.data,
    required this.view,
    required this.period,
    required this.onViewChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // Custom ranges have no bar buckets - force donut and hide the toggle.
    final isCustom = period == DashboardPeriod.custom;
    final effectiveView = isCustom ? DashboardChartView.donut : view;

    return BaseCard(
      padding: EdgeInsets.all(theme.spacings.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: effectiveView == DashboardChartView.donut
                ? _DonutContent(data: data)
                : _BarContent(data: data),
          ),
          if (!isCustom) ...[
            SizedBox(width: theme.spacings.sm),
            SegmentedToggle<DashboardChartView>(
              value: effectiveView,
              options: const [
                SegmentedToggleOption(
                  value: DashboardChartView.donut,
                  icon: Icons.donut_large_rounded,
                ),
                SegmentedToggleOption(
                  value: DashboardChartView.bar,
                  icon: Icons.bar_chart_rounded,
                ),
              ],
              onChanged: onViewChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalColumn extends StatelessWidget {
  final Duration total;

  const _TotalColumn({required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Total hours', // TODO: l10n
          style: theme.commonTextStyles.caption.copyWith(
            color: palette.text.secondary,
          ),
        ),
        SizedBox(height: theme.spacings.xxs),
        Text(
          DateFormatter.formatDurationHm(total),
          style: theme.commonTextStyles.displayLarge.copyWith(
            color: palette.text.primary,
          ),
        ),
      ],
    );
  }
}

class _DonutContent extends StatelessWidget {
  final ReportsData data;

  const _DonutContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        final projectDonut = _Donut(title: 'Project', slices: data.byProject); // TODO: l10n
        final taskDonut = _Donut(title: 'Task', slices: data.byTask); // TODO: l10n

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TotalColumn(total: data.totalDuration),
              SizedBox(width: theme.spacings.x2l),
              Expanded(child: projectDonut),
              SizedBox(width: theme.spacings.x2l),
              Expanded(child: taskDonut),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TotalColumn(total: data.totalDuration),
            SizedBox(height: theme.spacings.lg),
            projectDonut,
            SizedBox(height: theme.spacings.x2l),
            taskDonut,
          ],
        );
      },
    );
  }
}

class _Donut extends StatelessWidget {
  final String title;
  final List<ReportSlice> slices;

  const _Donut({required this.title, required this.slices});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.commonTextStyles.labelMedium.copyWith(
            color: palette.text.secondary,
          ),
        ),
        SizedBox(height: theme.spacings.md),
        if (slices.isEmpty)
          SizedBox(
            height: 160,
            child: Center(
              child: Text(
                'No time logged for this period.', // TODO: l10n
                style: theme.commonTextStyles.body2.copyWith(
                  color: palette.text.muted,
                ),
              ),
            ),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: PieChart(
                  PieChartData(
                    sections: slices.map((slice) {
                      return PieChartSectionData(
                        value: slice.duration.inMinutes.toDouble(),
                        color: slice.id.isEmpty
                            ? palette.text.muted
                            : BadgeUtils.getBadgeColor(slice.id).$2,
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
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...slices.take(_maxLegendRows).map((slice) {
                      return Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: theme.spacings.xxs),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: slice.id.isEmpty
                                    ? palette.text.muted
                                    : BadgeUtils.getBadgeColor(slice.id).$2,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: theme.spacings.sm),
                            Flexible(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 140),
                                child: Text(
                                  slice.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      theme.commonTextStyles.caption.copyWith(
                                    color: palette.text.primary,
                                  ),
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
                    }),
                    if (slices.length > _maxLegendRows)
                      _LegendMoreRow(
                        hidden: slices
                            .skip(_maxLegendRows)
                            .map((s) => (
                                  label: s.label,
                                  duration: s.duration,
                                  percentOfTotal: s.percentOfTotal,
                                ))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Collapsed tail of a donut legend: an accented "+N more" row that reveals
/// the remaining slices in a tooltip on hover.
class _LegendMoreRow extends StatelessWidget {
  final List<({String label, Duration duration, double percentOfTotal})>
      hidden;

  const _LegendMoreRow({required this.hidden});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final message = hidden
        .map((s) => '${s.label}  ${_formatHours(s.duration)} '
            '(${(s.percentOfTotal * 100).round()}%)')
        .join('\n');

    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 200),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: theme.spacings.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Aligns with the color dots above (dot width + gap).
              SizedBox(width: 8 + theme.spacings.sm),
              Text(
                '+${hidden.length} more', // TODO: l10n
                style: theme.commonTextStyles.caption.copyWith(
                  color: palette.accent.primary,
                ),
              ),
              SizedBox(width: theme.spacings.xxs),
              Icon(
                Icons.expand_more_rounded,
                size: 14,
                color: palette.accent.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarContent extends StatelessWidget {
  final ReportsData data;

  const _BarContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TotalColumn(total: data.totalDuration),
              SizedBox(width: theme.spacings.x2l),
              Expanded(child: StackedBarChart(bars: data.bars)),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TotalColumn(total: data.totalDuration),
            SizedBox(height: theme.spacings.lg),
            StackedBarChart(bars: data.bars),
          ],
        );
      },
    );
  }
}
