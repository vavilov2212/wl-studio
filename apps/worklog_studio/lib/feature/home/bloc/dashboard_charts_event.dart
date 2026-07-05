part of 'dashboard_charts_bloc.dart';

@freezed
sealed class DashboardChartsEvent with _$DashboardChartsEvent {
  const factory DashboardChartsEvent.periodChanged(DashboardPeriod period) =
      DashboardPeriodChanged;

  const factory DashboardChartsEvent.viewChanged(DashboardChartView view) =
      DashboardViewChanged;

  const factory DashboardChartsEvent.periodStepped(int direction) =
      DashboardPeriodStepped;

  const factory DashboardChartsEvent.customRangeSelected(
    DateTime start,
    DateTime end,
  ) = DashboardCustomRangeSelected;
}
