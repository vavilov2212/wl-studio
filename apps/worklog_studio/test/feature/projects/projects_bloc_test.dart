import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/projects_filters.dart';
import 'package:worklog_studio/domain/projects_sort.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/feature/projects/bloc/projects_bloc.dart';
import 'package:worklog_studio/feature/projects/presentation/components/project_list.dart';

void main() {
  group('ProjectsBloc', () {
    test('initial state has correct defaults', () {
      final bloc = ProjectsBloc();
      expect(bloc.state.viewMode, ProjectViewMode.table);
      expect(bloc.state.filters, const ProjectsFilters());
      expect(bloc.state.filterExpandedOverride, isNull);
      expect(bloc.state.sortField, ProjectsSortField.name);
      expect(bloc.state.sortDirection, SortDirection.asc);
      expect(bloc.state.sortExpanded, isFalse);
      bloc.close();
    });

    test('ProjectsViewModeChanged updates viewMode', () async {
      final bloc = ProjectsBloc();
      bloc.add(ProjectsViewModeChanged(ProjectViewMode.cards));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.viewMode, ProjectViewMode.cards);
      await bloc.close();
    });

    test('ProjectsFilterChanged updates filters', () async {
      final bloc = ProjectsBloc();
      const filters = ProjectsFilters(statuses: {ProjectStatus.open});
      bloc.add(ProjectsFilterChanged(filters));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.filters.statuses, {ProjectStatus.open});
      await bloc.close();
    });

    test('ProjectsFilterExpandedOverrideSet sets and clears override', () async {
      final bloc = ProjectsBloc();
      bloc.add(ProjectsFilterExpandedOverrideSet(false));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.filterExpandedOverride, isFalse);
      bloc.add(ProjectsFilterExpandedOverrideSet(null));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.filterExpandedOverride, isNull);
      await bloc.close();
    });

    test('ProjectsSortFieldChanged updates sortField', () async {
      final bloc = ProjectsBloc();
      bloc.add(ProjectsSortFieldChanged(ProjectsSortField.timeTracked));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.sortField, ProjectsSortField.timeTracked);
      await bloc.close();
    });

    test('ProjectsSortDirectionChanged updates sortDirection', () async {
      final bloc = ProjectsBloc();
      bloc.add(ProjectsSortDirectionChanged(SortDirection.desc));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.sortDirection, SortDirection.desc);
      await bloc.close();
    });

    test('ProjectsSortExpandedSet toggles sortExpanded', () async {
      final bloc = ProjectsBloc();
      bloc.add(ProjectsSortExpandedSet(true));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.sortExpanded, isTrue);
      await bloc.close();
    });

    test('events do not cross-contaminate state fields', () async {
      final bloc = ProjectsBloc();
      bloc.add(ProjectsViewModeChanged(ProjectViewMode.cards));
      bloc.add(ProjectsFilterChanged(
        const ProjectsFilters(statuses: {ProjectStatus.open}),
      ));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.viewMode, ProjectViewMode.cards);
      expect(bloc.state.filters.statuses, {ProjectStatus.open});
      expect(bloc.state.sortField, ProjectsSortField.name);
      await bloc.close();
    });
  });
}
