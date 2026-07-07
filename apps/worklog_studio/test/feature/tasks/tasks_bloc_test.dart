import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/domain/tasks_filters.dart';
import 'package:worklog_studio/domain/tasks_sort.dart';
import 'package:worklog_studio/feature/tasks/bloc/tasks_bloc.dart';
import 'package:worklog_studio/feature/tasks/presentation/components/task_list.dart';

void main() {
  group('TasksBloc', () {
    test('initial state has correct defaults', () {
      final bloc = TasksBloc();
      expect(bloc.state.viewMode, TaskViewMode.table);
      expect(bloc.state.filters, const TasksFilters());
      expect(bloc.state.filterExpandedOverride, isNull);
      expect(bloc.state.sortField, TasksSortField.name);
      expect(bloc.state.sortDirection, SortDirection.asc);
      expect(bloc.state.sortExpanded, isFalse);
      bloc.close();
    });

    test('TasksViewModeChanged updates viewMode', () async {
      final bloc = TasksBloc();
      bloc.add(TasksViewModeChanged(TaskViewMode.cards));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.viewMode, TaskViewMode.cards);
      await bloc.close();
    });

    test('TasksFilterChanged updates filters', () async {
      final bloc = TasksBloc();
      const filters = TasksFilters(projectIds: {'p1'});
      bloc.add(TasksFilterChanged(filters));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.filters.projectIds, {'p1'});
      await bloc.close();
    });

    test('TasksFilterExpandedOverrideSet sets and clears override', () async {
      final bloc = TasksBloc();
      bloc.add(TasksFilterExpandedOverrideSet(true));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.filterExpandedOverride, isTrue);
      bloc.add(TasksFilterExpandedOverrideSet(null));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.filterExpandedOverride, isNull);
      await bloc.close();
    });

    test('TasksSortFieldChanged updates sortField', () async {
      final bloc = TasksBloc();
      bloc.add(TasksSortFieldChanged(TasksSortField.timeTracked));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.sortField, TasksSortField.timeTracked);
      await bloc.close();
    });

    test('TasksSortDirectionChanged updates sortDirection', () async {
      final bloc = TasksBloc();
      bloc.add(TasksSortDirectionChanged(SortDirection.desc));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.sortDirection, SortDirection.desc);
      await bloc.close();
    });

    test('TasksSortExpandedSet toggles sortExpanded', () async {
      final bloc = TasksBloc();
      bloc.add(TasksSortExpandedSet(true));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.sortExpanded, isTrue);
      await bloc.close();
    });

    test('events do not cross-contaminate state fields', () async {
      final bloc = TasksBloc();
      bloc.add(TasksViewModeChanged(TaskViewMode.cards));
      bloc.add(TasksFilterChanged(const TasksFilters(projectIds: {'p1'})));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.viewMode, TaskViewMode.cards);
      expect(bloc.state.filters.projectIds, {'p1'});
      expect(bloc.state.sortField, TasksSortField.name);
      await bloc.close();
    });
  });
}
