import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:worklog_studio/data/system_clock.dart';
import 'package:worklog_studio/domain/time_tracker.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';

part 'reports_event.dart';
part 'reports_state.dart';
part 'reports_bloc.freezed.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final Clock _clock;

  ReportsBloc({Clock? clock}) : this._(clock ?? SystemClock());

  ReportsBloc._(Clock clock)
      : _clock = clock,
        super(
          ReportsState(
            period: DashboardPeriod.week,
            anchorDate: _truncate(clock.now(), DashboardPeriod.week),
          ),
        ) {
    on<ReportsPeriodChanged>(_onPeriodChanged);
    on<ReportsPeriodStepped>(_onPeriodStepped);
    on<ReportsCustomRangeSelected>(_onCustomRangeSelected);
    on<ReportsViewChanged>(_onViewChanged);
    on<ReportsSyncedFromDashboard>(_onSyncedFromDashboard);
  }

  void _onPeriodChanged(
    ReportsPeriodChanged event,
    Emitter<ReportsState> emit,
  ) {
    emit(state.copyWith(
      period: event.period,
      anchorDate: _truncate(_clock.now(), event.period),
    ));
  }

  void _onPeriodStepped(
    ReportsPeriodStepped event,
    Emitter<ReportsState> emit,
  ) {
    if (event.direction > 0 &&
        !canStepForward(state.period, state.anchorDate, _clock.now())) {
      return;
    }
    emit(state.copyWith(
      anchorDate: _stepAnchor(state.period, state.anchorDate, event.direction),
    ));
  }

  void _onCustomRangeSelected(
    ReportsCustomRangeSelected event,
    Emitter<ReportsState> emit,
  ) {
    emit(state.copyWith(
      period: DashboardPeriod.custom,
      customRangeStart: event.start,
      customRangeEnd: event.end,
    ));
  }

  void _onViewChanged(
    ReportsViewChanged event,
    Emitter<ReportsState> emit,
  ) {
    emit(state.copyWith(view: event.view));
  }

  void _onSyncedFromDashboard(
    ReportsSyncedFromDashboard event,
    Emitter<ReportsState> emit,
  ) {
    emit(state.copyWith(
      period: event.period,
      anchorDate: event.anchorDate,
      view: event.view,
      customRangeStart: event.customRangeStart,
      customRangeEnd: event.customRangeEnd,
    ));
  }

  static bool canStepForward(
    DashboardPeriod period,
    DateTime anchorDate,
    DateTime now,
  ) {
    if (period == DashboardPeriod.custom) return false;
    return _truncate(anchorDate, period).isBefore(_truncate(now, period));
  }

  static DateTime _truncate(DateTime date, DashboardPeriod period) {
    return period == DashboardPeriod.month
        ? DateTime(date.year, date.month, 1)
        : DateTime(date.year, date.month, date.day);
  }

  static DateTime _stepAnchor(
    DashboardPeriod period,
    DateTime anchor,
    int direction,
  ) {
    switch (period) {
      case DashboardPeriod.today:
        return anchor.add(Duration(days: direction));
      case DashboardPeriod.week:
        return anchor.add(Duration(days: 7 * direction));
      case DashboardPeriod.month:
        return DateTime(anchor.year, anchor.month + direction, 1);
      case DashboardPeriod.custom:
        return anchor;
    }
  }
}
