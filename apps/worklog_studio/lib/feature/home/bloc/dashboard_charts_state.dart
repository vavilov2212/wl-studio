part of 'dashboard_charts_bloc.dart';

@freezed
abstract class DashboardChartsState with _$DashboardChartsState {
  const DashboardChartsState._();

  const factory DashboardChartsState({
    required DashboardPeriod period,
    required DateTime anchorDate,
    @Default(DashboardChartView.donut) DashboardChartView view,
  }) = _DashboardChartsState;
}
