part of 'reports_bloc.dart';

abstract class ReportsEvent {}

class ReportsPeriodChanged extends ReportsEvent {
  final DashboardPeriod period;
  ReportsPeriodChanged(this.period);
}

class ReportsPeriodStepped extends ReportsEvent {
  final int direction; // -1 or +1
  ReportsPeriodStepped(this.direction);
}

class ReportsCustomRangeSelected extends ReportsEvent {
  final DateTime start;
  final DateTime end;
  ReportsCustomRangeSelected(this.start, this.end);
}

class ReportsViewChanged extends ReportsEvent {
  final DashboardChartView view;
  ReportsViewChanged(this.view);
}

/// Mirrors the Dashboard charts card state into Reports so a jump between the
/// pages lands on the same period, range and chart view.
class ReportsSyncedFromDashboard extends ReportsEvent {
  final DashboardPeriod period;
  final DateTime anchorDate;
  final DashboardChartView view;
  final DateTime? customRangeStart;
  final DateTime? customRangeEnd;

  ReportsSyncedFromDashboard({
    required this.period,
    required this.anchorDate,
    required this.view,
    this.customRangeStart,
    this.customRangeEnd,
  });
}
