import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';
import 'package:worklog_studio/feature/reports/bloc/reports_bloc.dart';
import 'package:worklog_studio/feature/reports/presentation/components/reports_summary_panel.dart';
import 'package:worklog_studio/feature/reports/presentation/components/reports_table.dart';
import 'package:worklog_studio/feature/reports/reports_aggregator.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      builder: (context, reportsState) {
        return Selector<EntityResolver, List<ResolvedTimeEntry>>(
          selector: (context, resolver) => resolver.getResolvedTimeEntries(),
          shouldRebuild: (prev, next) =>
              !const ListEquality<ResolvedTimeEntry>().equals(prev, next),
          builder: (context, entries, _) {
            final data = ReportsAggregator.aggregate(
              entries: entries,
              period: reportsState.period,
              anchorDate: reportsState.anchorDate,
              now: DateTime.now(),
              customRangeStart: reportsState.customRangeStart,
              customRangeEnd: reportsState.customRangeEnd,
            );
            final isEmpty = data.totalDuration == Duration.zero;
            final theme = context.theme;
            final palette = theme.colorsPalette;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacings.x2l,
                theme.spacings.x2l,
                theme.spacings.x2l,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reports', // TODO: l10n
                        style: theme.commonTextStyles.h3.copyWith(
                          color: palette.text.primary,
                        ),
                      ),
                      _PeriodToolbar(state: reportsState),
                    ],
                  ),
                  SizedBox(height: theme.spacings.lg),
                  if (isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'No time logged for this period.', // TODO: l10n
                          style: theme.commonTextStyles.body.copyWith(
                            color: palette.text.muted,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    ReportsSummaryPanel(data: data),
                    SizedBox(height: theme.spacings.lg),
                    Expanded(child: ReportsTable(data: data)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PeriodToolbar extends StatelessWidget {
  final ReportsState state;

  const _PeriodToolbar({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final bloc = context.read<ReportsBloc>();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 110,
          child: Select<DashboardPeriod>(
            value: state.period,
            minWidth: 110,
            options: const [
              SelectOption(value: DashboardPeriod.today, label: 'Today'), // TODO: l10n
              SelectOption(value: DashboardPeriod.week, label: 'Week'), // TODO: l10n
              SelectOption(value: DashboardPeriod.month, label: 'Month'), // TODO: l10n
              SelectOption(value: DashboardPeriod.custom, label: 'Custom...'), // TODO: l10n
            ],
            onChanged: (value) {
              if (value == null) return;
              if (value == DashboardPeriod.custom) {
                _pickCustomRange(context, bloc);
              } else {
                bloc.add(ReportsPeriodChanged(value));
              }
            },
          ),
        ),
        SizedBox(width: theme.spacings.sm),
        if (state.period != DashboardPeriod.custom) ...[
          _StepperButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => bloc.add(ReportsPeriodStepped(-1)),
          ),
          SizedBox(width: theme.spacings.xxs),
        ],
        if (state.period == DashboardPeriod.custom)
          _CustomRangeLabel(state: state, bloc: bloc)
        else
          Text(
            ReportsAggregator.aggregate(
              entries: const [],
              period: state.period,
              anchorDate: state.anchorDate,
              now: DateTime.now(),
              customRangeStart: state.customRangeStart,
              customRangeEnd: state.customRangeEnd,
            ).rangeLabel,
            style: theme.commonTextStyles.body2
                .copyWith(color: palette.text.secondary),
          ),
        if (state.period != DashboardPeriod.custom) ...[
          SizedBox(width: theme.spacings.xxs),
          _StepperButton(
            icon: Icons.chevron_right_rounded,
            enabled: ReportsBloc.canStepForward(
              state.period,
              state.anchorDate,
              DateTime.now(),
            ),
            onTap: () => bloc.add(ReportsPeriodStepped(1)),
          ),
        ],
      ],
    );
  }
}

class _CustomRangeLabel extends StatelessWidget {
  final ReportsState state;
  final ReportsBloc bloc;

  const _CustomRangeLabel({required this.state, required this.bloc});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final start = state.customRangeStart;
    final end = state.customRangeEnd;

    final label = (start != null && end != null)
        ? ReportsAggregator.aggregate(
            entries: const [],
            period: DashboardPeriod.custom,
            anchorDate: start,
            now: DateTime.now(),
            customRangeStart: start,
            customRangeEnd: end,
          ).rangeLabel
        : 'Custom'; // TODO: l10n

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
          padding: EdgeInsets.symmetric(horizontal: theme.spacings.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.commonTextStyles.body2.copyWith(
                  color: palette.text.secondary,
                ),
              ),
              SizedBox(width: theme.spacings.xxs),
              Icon(
                Icons.edit_calendar_rounded,
                size: 14,
                color: palette.text.muted,
              ),
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

Future<void> _pickCustomRange(
  BuildContext context,
  ReportsBloc bloc, {
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
                bloc.add(ReportsCustomRangeSelected(range.start, range.end));
                Navigator.of(dialogContext).pop();
              },
            ),
          ),
        ),
      );
    },
  );
}
