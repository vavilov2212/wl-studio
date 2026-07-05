import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worklog_studio/domain/history_filters.dart';
import 'package:worklog_studio/domain/history_sort.dart';
import 'package:worklog_studio/domain/projects_filters.dart';
import 'package:worklog_studio/domain/projects_sort.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/domain/tasks_filters.dart';
import 'package:worklog_studio/domain/tasks_sort.dart';
import 'package:worklog_studio/feature/history/presentation/history_page.dart';
import 'package:worklog_studio/feature/projects/presentation/projects_page.dart';
import 'package:worklog_studio/feature/tasks/presentation/tasks_page.dart';

/// Session-scoped (in-memory, lost on app restart) view-mode, filter, and
/// sort state for History/Tasks/Projects, lifted out of the page widgets so
/// it survives the pages being disposed when the user switches tabs.
///
/// [historyKpiStripVisible] is persisted across restarts via SharedPreferences.
class PageUiPreferences extends ChangeNotifier {
  static const _kHistoryKpiStripVisible = 'history_kpi_strip_visible';

  HistoryViewMode _historyViewMode = HistoryViewMode.table;
  HistoryFilters _historyFilters = const HistoryFilters();
  bool? _historyFilterExpandedOverride;
  HistorySortField _historySortField = HistorySortField.date;
  SortDirection _historySortDirection = SortDirection.desc;
  bool? _historySortExpandedOverride;
  bool _historyKpiStripVisible = true;

  PageUiPreferences() {
    _loadPersistedPrefs();
  }

  Future<void> _loadPersistedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _historyKpiStripVisible =
        prefs.getBool(_kHistoryKpiStripVisible) ?? true;
    notifyListeners();
  }

  TaskViewMode _tasksViewMode = TaskViewMode.table;
  TasksFilters _tasksFilters = const TasksFilters();
  bool? _tasksFilterExpandedOverride;
  TasksSortField _tasksSortField = TasksSortField.name;
  SortDirection _tasksSortDirection = SortDirection.asc;
  bool? _tasksSortExpandedOverride;

  ProjectViewMode _projectsViewMode = ProjectViewMode.table;
  ProjectsFilters _projectsFilters = const ProjectsFilters();
  bool? _projectsFilterExpandedOverride;
  ProjectsSortField _projectsSortField = ProjectsSortField.name;
  SortDirection _projectsSortDirection = SortDirection.asc;
  bool? _projectsSortExpandedOverride;

  HistoryViewMode get historyViewMode => _historyViewMode;
  HistoryFilters get historyFilters => _historyFilters;
  bool? get historyFilterExpandedOverride => _historyFilterExpandedOverride;
  HistorySortField get historySortField => _historySortField;
  SortDirection get historySortDirection => _historySortDirection;
  bool? get historySortExpandedOverride => _historySortExpandedOverride;
  bool get historyKpiStripVisible => _historyKpiStripVisible;

  TaskViewMode get tasksViewMode => _tasksViewMode;
  TasksFilters get tasksFilters => _tasksFilters;
  bool? get tasksFilterExpandedOverride => _tasksFilterExpandedOverride;
  TasksSortField get tasksSortField => _tasksSortField;
  SortDirection get tasksSortDirection => _tasksSortDirection;
  bool? get tasksSortExpandedOverride => _tasksSortExpandedOverride;

  ProjectViewMode get projectsViewMode => _projectsViewMode;
  ProjectsFilters get projectsFilters => _projectsFilters;
  bool? get projectsFilterExpandedOverride => _projectsFilterExpandedOverride;
  ProjectsSortField get projectsSortField => _projectsSortField;
  SortDirection get projectsSortDirection => _projectsSortDirection;
  bool? get projectsSortExpandedOverride => _projectsSortExpandedOverride;

  void setHistoryViewMode(HistoryViewMode mode) {
    _historyViewMode = mode;
    notifyListeners();
  }

  void setHistoryFilters(HistoryFilters filters) {
    _historyFilters = filters;
    notifyListeners();
  }

  void setHistoryFilterExpandedOverride(bool? value) {
    _historyFilterExpandedOverride = value;
    notifyListeners();
  }

  void setHistorySortField(HistorySortField field) {
    _historySortField = field;
    notifyListeners();
  }

  void setHistorySortDirection(SortDirection direction) {
    _historySortDirection = direction;
    notifyListeners();
  }

  void setHistorySortExpandedOverride(bool? value) {
    _historySortExpandedOverride = value;
    notifyListeners();
  }

  Future<void> setHistoryKpiStripVisible(bool value) async {
    _historyKpiStripVisible = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHistoryKpiStripVisible, value);
  }

  void setTasksViewMode(TaskViewMode mode) {
    _tasksViewMode = mode;
    notifyListeners();
  }

  void setTasksFilters(TasksFilters filters) {
    _tasksFilters = filters;
    notifyListeners();
  }

  void setTasksFilterExpandedOverride(bool? value) {
    _tasksFilterExpandedOverride = value;
    notifyListeners();
  }

  void setTasksSortField(TasksSortField field) {
    _tasksSortField = field;
    notifyListeners();
  }

  void setTasksSortDirection(SortDirection direction) {
    _tasksSortDirection = direction;
    notifyListeners();
  }

  void setTasksSortExpandedOverride(bool? value) {
    _tasksSortExpandedOverride = value;
    notifyListeners();
  }

  void setProjectsViewMode(ProjectViewMode mode) {
    _projectsViewMode = mode;
    notifyListeners();
  }

  void setProjectsFilters(ProjectsFilters filters) {
    _projectsFilters = filters;
    notifyListeners();
  }

  void setProjectsFilterExpandedOverride(bool? value) {
    _projectsFilterExpandedOverride = value;
    notifyListeners();
  }

  void setProjectsSortField(ProjectsSortField field) {
    _projectsSortField = field;
    notifyListeners();
  }

  void setProjectsSortDirection(SortDirection direction) {
    _projectsSortDirection = direction;
    notifyListeners();
  }

  void setProjectsSortExpandedOverride(bool? value) {
    _projectsSortExpandedOverride = value;
    notifyListeners();
  }
}
