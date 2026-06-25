import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:worklog_studio/data/system_clock.dart';
import 'package:worklog_studio/domain/time_tracker.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';

part 'dashboard_charts_event.dart';
part 'dashboard_charts_state.dart';
part 'dashboard_charts_bloc.freezed.dart';

enum DashboardChartView { donut, bar }

class DashboardChartsBloc extends Bloc<DashboardChartsEvent, DashboardChartsState> {
  final Clock _clock;

  DashboardChartsBloc({Clock? clock})
      : this._(clock ?? SystemClock());

  DashboardChartsBloc._(Clock clock)
      : _clock = clock,
        super(
          DashboardChartsState(
            period: DashboardPeriod.week,
            anchorDate: _truncate(clock.now(), DashboardPeriod.week),
          ),
        ) {
    on<DashboardPeriodChanged>(_onPeriodChanged);
    on<DashboardViewChanged>(_onViewChanged);
    on<DashboardPeriodStepped>(_onPeriodStepped);
  }

  void _onPeriodChanged(
    DashboardPeriodChanged event,
    Emitter<DashboardChartsState> emit,
  ) {
    emit(state.copyWith(
      period: event.period,
      anchorDate: _truncate(_clock.now(), event.period),
    ));
  }

  void _onViewChanged(
    DashboardViewChanged event,
    Emitter<DashboardChartsState> emit,
  ) {
    emit(state.copyWith(view: event.view));
  }

  void _onPeriodStepped(
    DashboardPeriodStepped event,
    Emitter<DashboardChartsState> emit,
  ) {
    emit(state.copyWith(
      anchorDate: _stepAnchor(state.period, state.anchorDate, event.direction),
    ));
  }

  static DateTime _truncate(DateTime date, DashboardPeriod period) {
    return period == DashboardPeriod.month
        ? DateTime(date.year, date.month, 1)
        : DateTime(date.year, date.month, date.day);
  }

  static DateTime _stepAnchor(DashboardPeriod period, DateTime anchor, int direction) {
    switch (period) {
      case DashboardPeriod.today:
        return anchor.add(Duration(days: direction));
      case DashboardPeriod.week:
        return anchor.add(Duration(days: 7 * direction));
      case DashboardPeriod.month:
        return DateTime(anchor.year, anchor.month + direction, 1);
    }
  }
}
