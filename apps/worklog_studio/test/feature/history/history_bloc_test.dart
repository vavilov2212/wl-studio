import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worklog_studio/domain/history_filters.dart';
import 'package:worklog_studio/domain/history_sort.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/feature/history/bloc/history_bloc.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HistoryBloc', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state has correct defaults', () async {
      final bloc = HistoryBloc();
      await Future<void>.delayed(Duration.zero); // let _init() settle
      expect(bloc.state.viewMode, HistoryViewMode.table);
      expect(bloc.state.filters, const HistoryFilters());
      expect(bloc.state.filterExpandedOverride, isNull);
      expect(bloc.state.sortField, HistorySortField.date);
      expect(bloc.state.sortDirection, SortDirection.desc);
      expect(bloc.state.sortExpanded, isFalse);
      expect(bloc.state.kpiStripVisible, isTrue);
      await bloc.close();
    });

    test('HistoryViewModeChanged updates viewMode', () async {
      final bloc = HistoryBloc();
      bloc.add(HistoryViewModeChanged(HistoryViewMode.cards));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.viewMode, HistoryViewMode.cards);
      await bloc.close();
    });

    test('HistoryFilterChanged updates filters', () async {
      final bloc = HistoryBloc();
      const filters = HistoryFilters(taskIds: {'t1', 't2'});
      bloc.add(HistoryFilterChanged(filters));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.filters.taskIds, {'t1', 't2'});
      await bloc.close();
    });

    test('HistoryFilterExpandedOverrideSet sets override to true', () async {
      final bloc = HistoryBloc();
      bloc.add(HistoryFilterExpandedOverrideSet(true));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.filterExpandedOverride, isTrue);
      await bloc.close();
    });

    test('HistoryFilterExpandedOverrideSet sets override to null', () async {
      final bloc = HistoryBloc();
      bloc.add(HistoryFilterExpandedOverrideSet(true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(HistoryFilterExpandedOverrideSet(null));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.filterExpandedOverride, isNull);
      await bloc.close();
    });

    test('HistorySortFieldChanged updates sortField', () async {
      final bloc = HistoryBloc();
      bloc.add(HistorySortFieldChanged(HistorySortField.duration));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.sortField, HistorySortField.duration);
      await bloc.close();
    });

    test('HistorySortDirectionChanged updates sortDirection', () async {
      final bloc = HistoryBloc();
      bloc.add(HistorySortDirectionChanged(SortDirection.asc));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.sortDirection, SortDirection.asc);
      await bloc.close();
    });

    test('HistorySortExpandedSet toggles sortExpanded', () async {
      final bloc = HistoryBloc();
      bloc.add(HistorySortExpandedSet(true));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.sortExpanded, isTrue);
      bloc.add(HistorySortExpandedSet(false));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.sortExpanded, isFalse);
      await bloc.close();
    });

    test('HistoryKpiStripVisibilityChanged updates kpiStripVisible', () async {
      final bloc = HistoryBloc();
      await Future<void>.delayed(Duration.zero); // let _init() settle
      bloc.add(HistoryKpiStripVisibilityChanged(false));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.kpiStripVisible, isFalse);
      await bloc.close();
    });

    test('HistoryKpiStripVisibilityChanged persists to SharedPreferences',
        () async {
      final bloc = HistoryBloc();
      await Future<void>.delayed(Duration.zero); // let _init() settle
      bloc.add(HistoryKpiStripVisibilityChanged(false));
      await Future<void>.delayed(Duration.zero);
      await bloc.close();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('history_kpi_strip_visible'), isFalse);
    });

    test('kpiStripVisible is restored from SharedPreferences on init',
        () async {
      SharedPreferences.setMockInitialValues({
        'history_kpi_strip_visible': false,
      });
      final bloc = HistoryBloc();
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.kpiStripVisible, isFalse);
      await bloc.close();
    });

    test('events do not cross-contaminate state fields', () async {
      final bloc = HistoryBloc();
      bloc.add(HistoryViewModeChanged(HistoryViewMode.cards));
      bloc.add(HistoryFilterChanged(const HistoryFilters(taskIds: {'t1'})));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.viewMode, HistoryViewMode.cards);
      expect(bloc.state.filters.taskIds, {'t1'});
      expect(bloc.state.sortField, HistorySortField.date);
      expect(bloc.state.sortExpanded, isFalse);
      await bloc.close();
    });
  });
}
