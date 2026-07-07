import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/domain/projects_filters.dart';
import 'package:worklog_studio/domain/projects_sort.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/feature/projects/presentation/components/project_list.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class ProjectsEvent {}

class ProjectsViewModeChanged extends ProjectsEvent {
  final ProjectViewMode viewMode;
  ProjectsViewModeChanged(this.viewMode);
}

class ProjectsFilterChanged extends ProjectsEvent {
  final ProjectsFilters filters;
  ProjectsFilterChanged(this.filters);
}

class ProjectsFilterExpandedOverrideSet extends ProjectsEvent {
  final bool? value;
  ProjectsFilterExpandedOverrideSet(this.value);
}

class ProjectsSortFieldChanged extends ProjectsEvent {
  final ProjectsSortField field;
  ProjectsSortFieldChanged(this.field);
}

class ProjectsSortDirectionChanged extends ProjectsEvent {
  final SortDirection direction;
  ProjectsSortDirectionChanged(this.direction);
}

class ProjectsSortExpandedSet extends ProjectsEvent {
  final bool expanded;
  ProjectsSortExpandedSet(this.expanded);
}

// ── State ─────────────────────────────────────────────────────────────────────

class ProjectsState {
  final ProjectViewMode viewMode;
  final ProjectsFilters filters;
  final bool? filterExpandedOverride;
  final ProjectsSortField sortField;
  final SortDirection sortDirection;
  final bool sortExpanded;

  const ProjectsState({
    this.viewMode = ProjectViewMode.table,
    this.filters = const ProjectsFilters(),
    this.filterExpandedOverride,
    this.sortField = ProjectsSortField.name,
    this.sortDirection = SortDirection.asc,
    this.sortExpanded = false,
  });

  ProjectsState copyWith({
    ProjectViewMode? viewMode,
    ProjectsFilters? filters,
    Object? filterExpandedOverride = _sentinel,
    ProjectsSortField? sortField,
    SortDirection? sortDirection,
    bool? sortExpanded,
  }) {
    return ProjectsState(
      viewMode: viewMode ?? this.viewMode,
      filters: filters ?? this.filters,
      filterExpandedOverride: filterExpandedOverride == _sentinel
          ? this.filterExpandedOverride
          : filterExpandedOverride as bool?,
      sortField: sortField ?? this.sortField,
      sortDirection: sortDirection ?? this.sortDirection,
      sortExpanded: sortExpanded ?? this.sortExpanded,
    );
  }
}

const _sentinel = Object();

// ── BLoC ──────────────────────────────────────────────────────────────────────

class ProjectsBloc extends Bloc<ProjectsEvent, ProjectsState> {
  ProjectsBloc() : super(const ProjectsState()) {
    on<ProjectsViewModeChanged>(
      (e, emit) => emit(state.copyWith(viewMode: e.viewMode)),
    );
    on<ProjectsFilterChanged>(
      (e, emit) => emit(state.copyWith(filters: e.filters)),
    );
    on<ProjectsFilterExpandedOverrideSet>(
      (e, emit) =>
          emit(state.copyWith(filterExpandedOverride: e.value)),
    );
    on<ProjectsSortFieldChanged>(
      (e, emit) => emit(state.copyWith(sortField: e.field)),
    );
    on<ProjectsSortDirectionChanged>(
      (e, emit) => emit(state.copyWith(sortDirection: e.direction)),
    );
    on<ProjectsSortExpandedSet>(
      (e, emit) => emit(state.copyWith(sortExpanded: e.expanded)),
    );
  }
}
