import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worklog_studio/domain/history_filters.dart';
import 'package:worklog_studio/domain/history_sort.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_list.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class HistoryEvent {}

class HistoryViewModeChanged extends HistoryEvent {
  final HistoryViewMode viewMode;
  HistoryViewModeChanged(this.viewMode);
}

class HistoryFilterChanged extends HistoryEvent {
  final HistoryFilters filters;
  HistoryFilterChanged(this.filters);
}

class HistoryFilterExpandedOverrideSet extends HistoryEvent {
  final bool? value;
  HistoryFilterExpandedOverrideSet(this.value);
}

class HistorySortFieldChanged extends HistoryEvent {
  final HistorySortField field;
  HistorySortFieldChanged(this.field);
}

class HistorySortDirectionChanged extends HistoryEvent {
  final SortDirection direction;
  HistorySortDirectionChanged(this.direction);
}

class HistorySortExpandedSet extends HistoryEvent {
  final bool expanded;
  HistorySortExpandedSet(this.expanded);
}

class HistoryKpiStripVisibilityChanged extends HistoryEvent {
  final bool visible;
  HistoryKpiStripVisibilityChanged(this.visible);
}

// ── State ─────────────────────────────────────────────────────────────────────

class HistoryState {
  final HistoryViewMode viewMode;
  final HistoryFilters filters;
  final bool? filterExpandedOverride;
  final HistorySortField sortField;
  final SortDirection sortDirection;
  final bool sortExpanded;
  final bool kpiStripVisible;

  const HistoryState({
    this.viewMode = HistoryViewMode.table,
    this.filters = const HistoryFilters(),
    this.filterExpandedOverride,
    this.sortField = HistorySortField.date,
    this.sortDirection = SortDirection.desc,
    this.sortExpanded = false,
    this.kpiStripVisible = true,
  });

  HistoryState copyWith({
    HistoryViewMode? viewMode,
    HistoryFilters? filters,
    Object? filterExpandedOverride = _sentinel,
    HistorySortField? sortField,
    SortDirection? sortDirection,
    bool? sortExpanded,
    bool? kpiStripVisible,
  }) {
    return HistoryState(
      viewMode: viewMode ?? this.viewMode,
      filters: filters ?? this.filters,
      filterExpandedOverride: filterExpandedOverride == _sentinel
          ? this.filterExpandedOverride
          : filterExpandedOverride as bool?,
      sortField: sortField ?? this.sortField,
      sortDirection: sortDirection ?? this.sortDirection,
      sortExpanded: sortExpanded ?? this.sortExpanded,
      kpiStripVisible: kpiStripVisible ?? this.kpiStripVisible,
    );
  }
}

const _sentinel = Object();

// ── BLoC ──────────────────────────────────────────────────────────────────────

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  static const _kKpiStripVisible = 'history_kpi_strip_visible';

  HistoryBloc() : super(const HistoryState()) {
    on<HistoryViewModeChanged>(
      (e, emit) => emit(state.copyWith(viewMode: e.viewMode)),
    );
    on<HistoryFilterChanged>(
      (e, emit) => emit(state.copyWith(filters: e.filters)),
    );
    on<HistoryFilterExpandedOverrideSet>(
      (e, emit) => emit(state.copyWith(filterExpandedOverride: e.value)),
    );
    on<HistorySortFieldChanged>(
      (e, emit) => emit(state.copyWith(sortField: e.field)),
    );
    on<HistorySortDirectionChanged>(
      (e, emit) => emit(state.copyWith(sortDirection: e.direction)),
    );
    on<HistorySortExpandedSet>(
      (e, emit) => emit(state.copyWith(sortExpanded: e.expanded)),
    );
    on<HistoryKpiStripVisibilityChanged>(_onKpiStripVisibilityChanged);
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final visible = prefs.getBool(_kKpiStripVisible) ?? true;
    add(HistoryKpiStripVisibilityChanged(visible));
  }

  Future<void> _onKpiStripVisibilityChanged(
    HistoryKpiStripVisibilityChanged event,
    Emitter<HistoryState> emit,
  ) async {
    emit(state.copyWith(kpiStripVisible: event.visible));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKpiStripVisible, event.visible);
  }
}
