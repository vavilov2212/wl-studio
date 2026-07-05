import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/time_tracker.dart';
import 'package:worklog_studio/feature/home/bloc/dashboard_charts_bloc.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';

class _FixedClock implements Clock {
  final DateTime _now;
  _FixedClock(this._now);

  @override
  DateTime now() => _now;
}

Future<DashboardChartsState> pump(
  DashboardChartsBloc bloc,
  DashboardChartsEvent event,
) async {
  bloc.add(event);
  await Future<void>.delayed(Duration.zero);
  return bloc.state;
}

void main() {
  group('DashboardChartsBloc', () {
    test('initial state defaults to week period, donut view, anchored at clock "now"', () async {
      final bloc = DashboardChartsBloc(clock: _FixedClock(DateTime(2024, 1, 17)));
      expect(bloc.state.period, DashboardPeriod.week);
      expect(bloc.state.view, DashboardChartView.donut);
      expect(bloc.state.anchorDate, DateTime(2024, 1, 17));
      await bloc.close();
    });

    test('periodChanged switches period and re-anchors to "now", snapped per period', () async {
      final bloc = DashboardChartsBloc(clock: _FixedClock(DateTime(2024, 1, 17)));
      final monthState = await pump(
        bloc,
        const DashboardChartsEvent.periodChanged(DashboardPeriod.month),
      );
      expect(monthState.period, DashboardPeriod.month);
      expect(monthState.anchorDate, DateTime(2024, 1, 1));

      final todayState = await pump(
        bloc,
        const DashboardChartsEvent.periodChanged(DashboardPeriod.today),
      );
      expect(todayState.anchorDate, DateTime(2024, 1, 17));
      await bloc.close();
    });

    test('viewChanged switches between donut and bar', () async {
      final bloc = DashboardChartsBloc(clock: _FixedClock(DateTime(2024, 1, 17)));
      final state = await pump(bloc, const DashboardChartsEvent.viewChanged(DashboardChartView.bar));
      expect(state.view, DashboardChartView.bar);
      await bloc.close();
    });

    test('periodStepped on week period moves the anchor by 7 days', () async {
      final bloc = DashboardChartsBloc(clock: _FixedClock(DateTime(2024, 1, 17)));
      final back = await pump(bloc, const DashboardChartsEvent.periodStepped(-1));
      expect(back.anchorDate, DateTime(2024, 1, 10));
      final forward = await pump(bloc, const DashboardChartsEvent.periodStepped(1));
      expect(forward.anchorDate, DateTime(2024, 1, 17));
      await bloc.close();
    });

    test('periodStepped on today period moves the anchor by 1 day', () async {
      final bloc = DashboardChartsBloc(clock: _FixedClock(DateTime(2024, 1, 17)));
      await pump(bloc, const DashboardChartsEvent.periodChanged(DashboardPeriod.today));
      final state = await pump(bloc, const DashboardChartsEvent.periodStepped(-1));
      expect(state.anchorDate, DateTime(2024, 1, 16));
      await bloc.close();
    });

    test('periodStepped on month period moves by a calendar month, snapped to day 1', () async {
      final bloc = DashboardChartsBloc(clock: _FixedClock(DateTime(2024, 1, 17)));
      await pump(bloc, const DashboardChartsEvent.periodChanged(DashboardPeriod.month));
      final prev = await pump(bloc, const DashboardChartsEvent.periodStepped(-1));
      expect(prev.anchorDate, DateTime(2023, 12, 1));
      // Forward is allowed back up to (but not past) the current month.
      final next = await pump(bloc, const DashboardChartsEvent.periodStepped(1));
      expect(next.anchorDate, DateTime(2024, 1, 1));
      await bloc.close();
    });

    test('customRangeSelected sets period to custom, forces donut view, stores the range', () async {
      final bloc = DashboardChartsBloc(clock: _FixedClock(DateTime(2024, 1, 17)));
      await pump(bloc, const DashboardChartsEvent.viewChanged(DashboardChartView.bar));
      final state = await pump(
        bloc,
        DashboardChartsEvent.customRangeSelected(
          DateTime(2024, 1, 5),
          DateTime(2024, 1, 12),
        ),
      );
      expect(state.period, DashboardPeriod.custom);
      expect(state.view, DashboardChartView.donut);
      expect(state.customRangeStart, DateTime(2024, 1, 5));
      expect(state.customRangeEnd, DateTime(2024, 1, 12));
      await bloc.close();
    });

    test('periodStepped forward is a no-op once the period reaches "now"', () async {
      final bloc = DashboardChartsBloc(clock: _FixedClock(DateTime(2024, 1, 17)));
      // Already on the current week (anchored at "now") — stepping forward
      // would move into a future week with no data.
      final state = await pump(bloc, const DashboardChartsEvent.periodStepped(1));
      expect(state.anchorDate, DateTime(2024, 1, 17));
      await bloc.close();
    });

    test('periodStepped forward is allowed when the period is in the past', () async {
      final bloc = DashboardChartsBloc(clock: _FixedClock(DateTime(2024, 1, 17)));
      await pump(bloc, const DashboardChartsEvent.periodStepped(-1));
      final state = await pump(bloc, const DashboardChartsEvent.periodStepped(1));
      expect(state.anchorDate, DateTime(2024, 1, 17));
      await bloc.close();
    });

    test('canStepForward is false once anchored at the period containing now', () {
      expect(
        DashboardChartsBloc.canStepForward(
          DashboardPeriod.week,
          DateTime(2024, 1, 17),
          DateTime(2024, 1, 17),
        ),
        isFalse,
      );
      expect(
        DashboardChartsBloc.canStepForward(
          DashboardPeriod.week,
          DateTime(2024, 1, 10),
          DateTime(2024, 1, 17),
        ),
        isTrue,
      );
      expect(
        DashboardChartsBloc.canStepForward(
          DashboardPeriod.custom,
          DateTime(2024, 1, 10),
          DateTime(2024, 1, 17),
        ),
        isFalse,
      );
    });

    test('periodStepped is a no-op when period is custom', () async {
      final bloc = DashboardChartsBloc(clock: _FixedClock(DateTime(2024, 1, 17)));
      await pump(
        bloc,
        DashboardChartsEvent.customRangeSelected(
          DateTime(2024, 1, 5),
          DateTime(2024, 1, 12),
        ),
      );
      final state = await pump(bloc, const DashboardChartsEvent.periodStepped(1));
      expect(state.anchorDate, DateTime(2024, 1, 17));
      await bloc.close();
    });
  });
}
