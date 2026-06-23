import 'package:flutter/foundation.dart';
import 'package:worklog_studio/domain/history_filters.dart';
import 'package:worklog_studio/domain/projects_filters.dart';
import 'package:worklog_studio/domain/tasks_filters.dart';
import 'package:worklog_studio/feature/history/presentation/history_page.dart';
import 'package:worklog_studio/feature/projects/presentation/projects_page.dart';
import 'package:worklog_studio/feature/tasks/presentation/tasks_page.dart';

/// Session-scoped (in-memory, lost on app restart) view-mode and filter
/// state for History/Tasks/Projects, lifted out of the page widgets so it
/// survives the pages being disposed when the user switches tabs.
class PageUiPreferences extends ChangeNotifier {
  HistoryViewMode _historyViewMode = HistoryViewMode.table;
  HistoryFilters _historyFilters = const HistoryFilters();
  bool? _historyFilterExpandedOverride;

  TaskViewMode _tasksViewMode = TaskViewMode.table;
  TasksFilters _tasksFilters = const TasksFilters();
  bool? _tasksFilterExpandedOverride;

  ProjectViewMode _projectsViewMode = ProjectViewMode.table;
  ProjectsFilters _projectsFilters = const ProjectsFilters();
  bool? _projectsFilterExpandedOverride;

  HistoryViewMode get historyViewMode => _historyViewMode;
  HistoryFilters get historyFilters => _historyFilters;
  bool? get historyFilterExpandedOverride => _historyFilterExpandedOverride;

  TaskViewMode get tasksViewMode => _tasksViewMode;
  TasksFilters get tasksFilters => _tasksFilters;
  bool? get tasksFilterExpandedOverride => _tasksFilterExpandedOverride;

  ProjectViewMode get projectsViewMode => _projectsViewMode;
  ProjectsFilters get projectsFilters => _projectsFilters;
  bool? get projectsFilterExpandedOverride => _projectsFilterExpandedOverride;

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
}
