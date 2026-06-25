import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/home/bloc/dashboard_charts_bloc.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

const double _chartsWideBreakpoint = 900;

class DashboardChartsSection extends StatelessWidget {
  const DashboardChartsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardChartsBloc>(
      create: (_) => DashboardChartsBloc(),
      child: const _DashboardChartsSectionBody(),
    );
  }
}

class _DashboardChartsSectionBody extends StatelessWidget {
  const _DashboardChartsSectionBody();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return BlocBuilder<DashboardChartsBloc, DashboardChartsState>(
      builder: (context, chartsState) {
        return Selector<EntityResolver, List<ResolvedTimeEntry>>(
          selector: (context, resolver) => resolver.getResolvedTimeEntries(),
          shouldRebuild: (prev, next) => !const ListEquality().equals(prev, next),
          builder: (context, entries, child) {
            final data = DashboardChartAggregator.aggregate(
              entries: entries,
              period: chartsState.period,
              anchorDate: chartsState.anchorDate,
              now: DateTime.now(),
              customRangeStart: chartsState.customRangeStart,
              customRangeEnd: chartsState.customRangeEnd,
            );
            final isEmpty = data.byProject.isEmpty && data.byTask.isEmpty;

            return BaseCard(
              padding: EdgeInsets.all(theme.spacings.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChartsHeader(state: chartsState, rangeLabel: data.rangeLabel),
                  SizedBox(height: theme.spacings.lg),
                  if (isEmpty)
                    const _EmptyChartsState()
                  else if (chartsState.view == DashboardChartView.donut)
                    _DonutPair(data: data)
                  else
                    _BarChart(data: data),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ChartsHeader extends StatelessWidget {
  final DashboardChartsState state;
  final String rangeLabel;

  const _ChartsHeader({required this.state, required this.rangeLabel});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final bloc = context.read<DashboardChartsBloc>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _chartsWideBreakpoint;

        final periodControls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 110,
              child: Select<DashboardPeriod>(
                value: state.period,
                minWidth: 110,
                options: const [
                  SelectOption(value: DashboardPeriod.today, label: 'Today'),
                  SelectOption(value: DashboardPeriod.week, label: 'Week'),
                  SelectOption(value: DashboardPeriod.month, label: 'Month'),
                  SelectOption(value: DashboardPeriod.custom, label: 'Custom...'),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  if (value == DashboardPeriod.custom) {
                    _pickCustomRange(context, bloc);
                  } else {
                    bloc.add(DashboardChartsEvent.periodChanged(value));
                  }
                },
              ),
            ),
            SizedBox(width: theme.spacings.sm),
            if (state.period != DashboardPeriod.custom) ...[
              _StepperButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => bloc.add(const DashboardChartsEvent.periodStepped(-1)),
              ),
              SizedBox(width: theme.spacings.xxs),
            ],
            if (state.period == DashboardPeriod.custom)
              _CustomRangeLabel(state: state, rangeLabel: rangeLabel, bloc: bloc)
            else
              Text(
                rangeLabel,
                style: theme.commonTextStyles.body2.copyWith(color: palette.text.secondary),
              ),
            if (state.period != DashboardPeriod.custom) ...[
              SizedBox(width: theme.spacings.xxs),
              _StepperButton(
                icon: Icons.chevron_right_rounded,
                enabled: DashboardChartsBloc.canStepForward(
                  state.period,
                  state.anchorDate,
                  DateTime.now(),
                ),
                onTap: () => bloc.add(const DashboardChartsEvent.periodStepped(1)),
              ),
            ],
          ],
        );

        final viewToggle = state.period == DashboardPeriod.custom
            ? const SizedBox.shrink()
            : SegmentedToggle<DashboardChartView>(
                value: state.view,
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
                onChanged: (value) => bloc.add(DashboardChartsEvent.viewChanged(value)),
              );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [periodControls, viewToggle],
          );
        }

        return Wrap(
          spacing: theme.spacings.sm,
          runSpacing: theme.spacings.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [periodControls, viewToggle],
        );
      },
    );
  }
}

Future<void> _pickCustomRange(
  BuildContext context,
  DashboardChartsBloc bloc, {
  DateTimeRange? initialRange,
}) async {
  final now = DateTime.now();
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2000),
    lastDate: now,
    initialDateRange: initialRange,
  );
  if (picked != null) {
    bloc.add(DashboardChartsEvent.customRangeSelected(picked.start, picked.end));
  }
}

class _CustomRangeLabel extends StatelessWidget {
  final DashboardChartsState state;
  final String rangeLabel;
  final DashboardChartsBloc bloc;

  const _CustomRangeLabel({
    required this.state,
    required this.rangeLabel,
    required this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final start = state.customRangeStart;
    final end = state.customRangeEnd;

    return Material(
      color: Colors.transparent,
      borderRadius: theme.radiuses.sm.circular,
      child: InkWell(
        borderRadius: theme.radiuses.sm.circular,
        onTap: () => _pickCustomRange(
          context,
          bloc,
          initialRange: start != null && end != null
              ? DateTimeRange(start: start, end: end)
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacings.xxs,
            vertical: theme.spacings.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rangeLabel,
                style: theme.commonTextStyles.body2.copyWith(
                  color: palette.text.secondary,
                ),
              ),
              SizedBox(width: theme.spacings.xxs),
              Icon(Icons.edit_calendar_rounded, size: 14, color: palette.text.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _StepperButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final color = enabled ? palette.text.secondary : palette.text.muted;

    return Material(
      color: Colors.transparent,
      borderRadius: theme.radiuses.sm.circular,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: theme.radiuses.sm.circular,
        child: Padding(
          padding: EdgeInsets.all(theme.spacings.xxs),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _DonutPair extends StatelessWidget {
  final DashboardChartData data;

  const _DonutPair({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _chartsWideBreakpoint;
        final projectDonut = _Donut(title: 'Project', slices: data.byProject);
        final taskDonut = _Donut(title: 'Task', slices: data.byTask);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: projectDonut),
              SizedBox(width: theme.spacings.x2l),
              Expanded(child: taskDonut),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
  final List<DashboardSlice> slices;

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
          style: theme.commonTextStyles.labelMedium.copyWith(color: palette.text.secondary),
        ),
        SizedBox(height: theme.spacings.md),
        if (slices.isEmpty)
          SizedBox(
            height: 160,
            child: Center(
              child: Text(
                'No time logged for this period.',
                style: theme.commonTextStyles.body2.copyWith(color: palette.text.muted),
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
                        color: _colorFor(slice, palette),
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
                            color: _colorFor(slice, palette),
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

  Color _colorFor(DashboardSlice slice, ColorsPalette palette) {
    if (slice.id.isEmpty) return palette.text.muted;
    return BadgeUtils.getBadgeColor(slice.id).$2;
  }

  String _formatHours(Duration duration) {
    final hours = duration.inMinutes / 60;
    return '${hours.toStringAsFixed(1)}h';
  }
}

class _BarChart extends StatelessWidget {
  final DashboardChartData data;

  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final maxHours = data.bars
        .map((b) => b.duration.inMinutes / 60)
        .fold<double>(0, (max, v) => v > max ? v : max);
    final chartMaxY = maxHours <= 0 ? 1.0 : maxHours * 1.2;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: chartMaxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.bars.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: theme.spacings.xs),
                    child: Text(
                      data.bars[index].label,
                      style: theme.commonTextStyles.caption.copyWith(
                        color: palette.text.muted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: data.bars.asMap().entries.map((entry) {
            final hours = entry.value.duration.inMinutes / 60;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: hours,
                  color: palette.accent.primary,
                  width: 32,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _EmptyChartsState extends StatelessWidget {
  const _EmptyChartsState();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return SizedBox(
      height: 200,
      child: Center(
        child: Text(
          'No time logged for this period.',
          style: theme.commonTextStyles.body.copyWith(color: palette.text.muted),
        ),
      ),
    );
  }
}
