import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/core/services/app_navigation_controller.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/feature/common/presentation/components/stacked_bar_chart.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/home/bloc/dashboard_charts_bloc.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';
import 'package:worklog_studio/feature/reports/bloc/reports_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

const double _chartsWideBreakpoint = 900;

// Legend rows shown next to a donut before the rest collapses into a
// "+N more" tooltip row.
const int _maxLegendRows = 6;

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
                    StackedBarChart(bars: data.bars),
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

        final rightControls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.period != DashboardPeriod.custom) ...[
              SegmentedToggle<DashboardChartView>(
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
              ),
              SizedBox(width: theme.spacings.sm),
            ],
            _OpenInReportsButton(state: state, rangeLabel: rangeLabel),
          ],
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [periodControls, rightControls],
          );
        }

        return Wrap(
          spacing: theme.spacings.sm,
          runSpacing: theme.spacings.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [periodControls, rightControls],
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
  final theme = context.theme;
  final palette = theme.colorsPalette;

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.2),
    builder: (dialogContext) {
      return Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(
              color: palette.background.surface,
              borderRadius: theme.radiuses.md.circular,
              border: Border.all(color: palette.border.primary),
              boxShadow: [theme.shadows.md],
            ),
            padding: EdgeInsets.all(theme.spacings.sm),
            child: CalendarPicker(
              selectedRange: initialRange,
              lastDate: DateTime.now(),
              onRangeSelected: (range) {
                bloc.add(
                  DashboardChartsEvent.customRangeSelected(
                    range.start,
                    range.end,
                  ),
                );
                Navigator.of(dialogContext).pop();
              },
            ),
          ),
        ),
      );
    },
  );
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

/// Jumps to the Reports page mirroring the current charts setup; the tooltip
/// spells out exactly which period, range and chart view will carry over.
class _OpenInReportsButton extends StatelessWidget {
  final DashboardChartsState state;
  final String rangeLabel;

  const _OpenInReportsButton({required this.state, required this.rangeLabel});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    // Reports renders custom ranges donut-only, so demonstrate the view that
    // will actually appear after the jump.
    final effectiveView = state.period == DashboardPeriod.custom
        ? DashboardChartView.donut
        : state.view;
    final viewLabel = effectiveView == DashboardChartView.bar
        ? 'bar chart'
        : 'donut charts'; // TODO: l10n

    return Tooltip(
      message: 'Open in Reports: $rangeLabel, $viewLabel', // TODO: l10n
      waitDuration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        borderRadius: theme.radiuses.sm.circular,
        child: InkWell(
          onTap: () {
            context.read<ReportsBloc>().add(ReportsSyncedFromDashboard(
                  period: state.period,
                  anchorDate: state.anchorDate,
                  view: state.view,
                  customRangeStart: state.customRangeStart,
                  customRangeEnd: state.customRangeEnd,
                ));
            context.read<AppNavigationController>().openReports();
          },
          borderRadius: theme.radiuses.sm.circular,
          child: Padding(
            padding: EdgeInsets.all(theme.spacings.xxs),
            child: Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: palette.text.secondary,
            ),
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
                                color: _colorFor(slice, palette),
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

  Color _colorFor(DashboardSlice slice, ColorsPalette palette) {
    if (slice.id.isEmpty) return palette.text.muted;
    return BadgeUtils.getBadgeColor(slice.id).$2;
  }

  String _formatHours(Duration duration) {
    final hours = duration.inMinutes / 60;
    return '${hours.toStringAsFixed(1)}h';
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
        .map((s) => '${s.label}  ${_formatHoursTop(s.duration)} '
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

String _formatHoursTop(Duration duration) {
  final hours = duration.inMinutes / 60;
  return '${hours.toStringAsFixed(1)}h';
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
