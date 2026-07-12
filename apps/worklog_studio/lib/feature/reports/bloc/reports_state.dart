part of 'reports_bloc.dart';

@freezed
abstract class ReportsState with _$ReportsState {
  const ReportsState._();

  const factory ReportsState({
    required DashboardPeriod period,
    required DateTime anchorDate,
    DateTime? customRangeStart,
    DateTime? customRangeEnd,
  }) = _ReportsState;
}
