import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';
import 'package:worklog_studio/feature/reports/bloc/reports_bloc.dart';
import '../../helpers/test_fakes.dart';

void main() {
  group('ReportsBloc', () {
    // Fixed Monday: 2026-07-06 12:00
    late FakeClock clock;

    setUp(() {
      clock = FakeClock(DateTime(2026, 7, 6, 12, 0));
    });

    test('initial state: week period, anchorDate is truncated to week Monday', () async {
      final bloc = ReportsBloc(clock: clock);
      expect(bloc.state.period, equals(DashboardPeriod.week));
      expect(bloc.state.anchorDate, equals(DateTime(2026, 7, 6))); // Monday
      await bloc.close();
    });

    test('ReportsPeriodChanged(today) -> period changes, anchorDate resets to today', () async {
      final bloc = ReportsBloc(clock: clock);
      bloc.add(ReportsPeriodChanged(DashboardPeriod.today));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.period, equals(DashboardPeriod.today));
      expect(bloc.state.anchorDate, equals(DateTime(2026, 7, 6)));
      await bloc.close();
    });

    test('ReportsPeriodStepped(-1) on week -> anchorDate moves back 7 days', () async {
      final bloc = ReportsBloc(clock: clock);
      bloc.add(ReportsPeriodStepped(-1));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.anchorDate, equals(DateTime(2026, 6, 29)));
      await bloc.close();
    });

    test('ReportsPeriodStepped(+1) on current week -> no change (canStepForward guard)', () async {
      final bloc = ReportsBloc(clock: clock);
      final before = bloc.state.anchorDate;
      bloc.add(ReportsPeriodStepped(1));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.anchorDate, equals(before));
      await bloc.close();
    });

    test('ReportsPeriodStepped(+1) on past week -> anchorDate moves forward 7 days', () async {
      final bloc = ReportsBloc(clock: clock);
      bloc.add(ReportsPeriodStepped(-1)); // go to June 29 week
      await Future<void>.delayed(Duration.zero);
      bloc.add(ReportsPeriodStepped(1)); // back to July 6 week
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.anchorDate, equals(DateTime(2026, 7, 6)));
      await bloc.close();
    });

    test('ReportsCustomRangeSelected -> period becomes custom, dates set', () async {
      final bloc = ReportsBloc(clock: clock);
      final start = DateTime(2026, 7, 1);
      final end = DateTime(2026, 7, 5);
      bloc.add(ReportsCustomRangeSelected(start, end));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.period, equals(DashboardPeriod.custom));
      expect(bloc.state.customRangeStart, equals(start));
      expect(bloc.state.customRangeEnd, equals(end));
      await bloc.close();
    });

    test('canStepForward is false for current week', () {
      final now = DateTime(2026, 7, 6, 12, 0);
      final anchor = DateTime(2026, 7, 6); // current week
      expect(ReportsBloc.canStepForward(DashboardPeriod.week, anchor, now), isFalse);
    });

    test('canStepForward is true for past week', () {
      final now = DateTime(2026, 7, 6, 12, 0);
      final anchor = DateTime(2026, 6, 29); // previous week
      expect(ReportsBloc.canStepForward(DashboardPeriod.week, anchor, now), isTrue);
    });

    test('canStepForward is always false for custom period', () {
      final now = DateTime(2026, 7, 6);
      final anchor = DateTime(2026, 6, 1);
      expect(ReportsBloc.canStepForward(DashboardPeriod.custom, anchor, now), isFalse);
    });

    test('initial state: view is donut', () async {
      final bloc = ReportsBloc(clock: clock);
      expect(bloc.state.view, equals(DashboardChartView.donut));
      await bloc.close();
    });

    test('ReportsViewChanged(bar) -> view flips to bar', () async {
      final bloc = ReportsBloc(clock: clock);
      bloc.add(ReportsViewChanged(DashboardChartView.bar));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.view, equals(DashboardChartView.bar));
      await bloc.close();
    });

    test('ReportsSyncedFromDashboard mirrors period, anchor and view', () async {
      final bloc = ReportsBloc(clock: clock);
      bloc.add(ReportsSyncedFromDashboard(
        period: DashboardPeriod.month,
        anchorDate: DateTime(2026, 6, 1),
        view: DashboardChartView.bar,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.period, equals(DashboardPeriod.month));
      expect(bloc.state.anchorDate, equals(DateTime(2026, 6, 1)));
      expect(bloc.state.view, equals(DashboardChartView.bar));
      await bloc.close();
    });

    test('ReportsSyncedFromDashboard carries a custom range', () async {
      final bloc = ReportsBloc(clock: clock);
      final start = DateTime(2026, 6, 10);
      final end = DateTime(2026, 6, 20);
      bloc.add(ReportsSyncedFromDashboard(
        period: DashboardPeriod.custom,
        anchorDate: start,
        view: DashboardChartView.donut,
        customRangeStart: start,
        customRangeEnd: end,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.period, equals(DashboardPeriod.custom));
      expect(bloc.state.customRangeStart, equals(start));
      expect(bloc.state.customRangeEnd, equals(end));
      await bloc.close();
    });

    test('view survives period change and stepping', () async {
      final bloc = ReportsBloc(clock: clock);
      bloc.add(ReportsViewChanged(DashboardChartView.bar));
      await Future<void>.delayed(Duration.zero);
      bloc.add(ReportsPeriodChanged(DashboardPeriod.month));
      await Future<void>.delayed(Duration.zero);
      bloc.add(ReportsPeriodStepped(-1));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.view, equals(DashboardChartView.bar));
      await bloc.close();
    });
  });
}
