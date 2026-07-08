import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/domain/tasks_filters.dart';
import 'package:worklog_studio/domain/tasks_sort.dart';
import 'package:worklog_studio/feature/tasks/presentation/components/task_list.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class TasksEvent {}

class TasksViewModeChanged extends TasksEvent {
  final TaskViewMode viewMode;
  TasksViewModeChanged(this.viewMode);
}

class TasksFilterChanged extends TasksEvent {
  final TasksFilters filters;
  TasksFilterChanged(this.filters);
}

class TasksFilterExpandedOverrideSet extends TasksEvent {
  final bool? value;
  TasksFilterExpandedOverrideSet(this.value);
}

class TasksSortFieldChanged extends TasksEvent {
  final TasksSortField field;
  TasksSortFieldChanged(this.field);
}

class TasksSortDirectionChanged extends TasksEvent {
  final SortDirection direction;
  TasksSortDirectionChanged(this.direction);
}

class TasksSortExpandedSet extends TasksEvent {
  final bool expanded;
  TasksSortExpandedSet(this.expanded);
}

// ── State ─────────────────────────────────────────────────────────────────────

class TasksState {
  final TaskViewMode viewMode;
  final TasksFilters filters;
  final bool? filterExpandedOverride;
  final TasksSortField sortField;
  final SortDirection sortDirection;
  final bool sortExpanded;

  const TasksState({
    this.viewMode = TaskViewMode.table,
    this.filters = const TasksFilters(),
    this.filterExpandedOverride,
    this.sortField = TasksSortField.name,
    this.sortDirection = SortDirection.asc,
    this.sortExpanded = false,
  });

  TasksState copyWith({
    TaskViewMode? viewMode,
    TasksFilters? filters,
    Object? filterExpandedOverride = _sentinel,
    TasksSortField? sortField,
    SortDirection? sortDirection,
    bool? sortExpanded,
  }) {
    return TasksState(
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

class TasksBloc extends Bloc<TasksEvent, TasksState> {
  TasksBloc() : super(const TasksState()) {
    on<TasksViewModeChanged>(
      (e, emit) => emit(state.copyWith(viewMode: e.viewMode)),
    );
    on<TasksFilterChanged>(
      (e, emit) => emit(state.copyWith(filters: e.filters)),
    );
    on<TasksFilterExpandedOverrideSet>(
      (e, emit) =>
          emit(state.copyWith(filterExpandedOverride: e.value)),
    );
    on<TasksSortFieldChanged>(
      (e, emit) => emit(state.copyWith(sortField: e.field)),
    );
    on<TasksSortDirectionChanged>(
      (e, emit) => emit(state.copyWith(sortDirection: e.direction)),
    );
    on<TasksSortExpandedSet>(
      (e, emit) => emit(state.copyWith(sortExpanded: e.expanded)),
    );
  }
}
