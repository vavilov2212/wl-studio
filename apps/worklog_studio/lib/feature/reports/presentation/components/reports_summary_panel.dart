import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/utils/chart_scale.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';
import 'package:worklog_studio/feature/reports/reports_aggregator.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

const double _wideBreakpoint = 900;

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: slices.map((slice) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: theme.spacings.xxs),
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
              Expanded(child: _ReportsStackedBarChart(bars: data.bars)),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TotalColumn(total: data.totalDuration),
            SizedBox(height: theme.spacings.lg),
            _ReportsStackedBarChart(bars: data.bars),
          ],
        );
      },
    );
  }
}

class _ReportsStackedBarChart extends StatelessWidget {
  final List<ReportsBar> bars;

  const _ReportsStackedBarChart({required this.bars});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final maxHours = bars
        .map((b) => b.total.inMinutes / 60)
        .fold<double>(0, (max, v) => v > max ? v : max);
    final scale = chartScale(maxHours);

    return SizedBox(
      height: 220,
      child: BarChart(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        BarChartData(
          maxY: scale.maxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(enabled: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: scale.interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: palette.border.primary.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: scale.interval,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) return const SizedBox.shrink();
                  final label = value % 1 == 0
                      ? '${value.toInt()}h'
                      : '${value.toStringAsFixed(1)}h';
                  return Text(
                    label,
                    style: theme.commonTextStyles.caption.copyWith(
                      color: palette.text.muted,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= bars.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: theme.spacings.xs),
                    child: Text(
                      bars[index].label,
                      style: theme.commonTextStyles.caption.copyWith(
                        color: palette.text.muted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: bars.asMap().entries.map((entry) {
            final index = entry.key;
            final bar = entry.value;
            final items = <BarChartRodStackItem>[];
            var from = 0.0;
            for (final seg in bar.segments) {
              final to = from + seg.duration.inMinutes / 60;
              items.add(BarChartRodStackItem(
                from,
                to,
                seg.projectId.isEmpty
                    ? palette.text.muted
                    : BadgeUtils.getBadgeColor(seg.projectId).$2,
              ));
              from = to;
            }
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: from,
                  width: 32,
                  borderRadius: BorderRadius.circular(4),
                  rodStackItems: items,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
