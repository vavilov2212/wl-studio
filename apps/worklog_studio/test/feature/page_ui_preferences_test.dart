import 'package:flutter_test/flutter_test.dart';
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
import 'package:worklog_studio/state/page_ui_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PageUiPreferences', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to table view mode and empty filters for every page', () {
      final prefs = PageUiPreferences();

      expect(prefs.historyViewMode, HistoryViewMode.table);
      expect(prefs.historyFilters.taskIds, isEmpty);
      expect(prefs.historyFilterExpandedOverride, isNull);

      expect(prefs.tasksViewMode, TaskViewMode.table);
      expect(prefs.tasksFilters.activeCount, 0);
      expect(prefs.tasksFilterExpandedOverride, isNull);

      expect(prefs.projectsViewMode, ProjectViewMode.table);
      expect(prefs.projectsFilters.activeCount, 0);
      expect(prefs.projectsFilterExpandedOverride, isNull);
    });

    test('setHistoryViewMode updates the value and notifies listeners', () {
      final prefs = PageUiPreferences();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.setHistoryViewMode(HistoryViewMode.cards);

      expect(prefs.historyViewMode, HistoryViewMode.cards);
      expect(notified, isTrue);
    });

    test('setHistoryFilters updates the value and notifies listeners', () {
      final prefs = PageUiPreferences();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.setHistoryFilters(const HistoryFilters(taskIds: {'t1'}));

      expect(prefs.historyFilters.taskIds, {'t1'});
      expect(notified, isTrue);
    });

    test('setHistoryFilterExpandedOverride updates the value and notifies listeners', () {
      final prefs = PageUiPreferences();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.setHistoryFilterExpandedOverride(true);

      expect(prefs.historyFilterExpandedOverride, isTrue);
      expect(notified, isTrue);
    });

    test('setTasksViewMode updates the value and notifies listeners', () {
      final prefs = PageUiPreferences();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.setTasksViewMode(TaskViewMode.cards);

      expect(prefs.tasksViewMode, TaskViewMode.cards);
      expect(notified, isTrue);
    });

    test('setTasksFilters updates the value and notifies listeners', () {
      final prefs = PageUiPreferences();

      prefs.setTasksFilters(const TasksFilters(projectIds: {'p1'}));

      expect(prefs.tasksFilters.projectIds, {'p1'});
    });

    test('setTasksFilterExpandedOverride updates the value', () {
      final prefs = PageUiPreferences();

      prefs.setTasksFilterExpandedOverride(false);

      expect(prefs.tasksFilterExpandedOverride, isFalse);
    });

    test('setProjectsViewMode updates the value and notifies listeners', () {
      final prefs = PageUiPreferences();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.setProjectsViewMode(ProjectViewMode.cards);

      expect(prefs.projectsViewMode, ProjectViewMode.cards);
      expect(notified, isTrue);
    });

    test('setProjectsFilters updates the value and notifies listeners', () {
      final prefs = PageUiPreferences();

      prefs.setProjectsFilters(const ProjectsFilters());

      expect(prefs.projectsFilters.activeCount, 0);
    });

    test('setProjectsFilterExpandedOverride updates the value', () {
      final prefs = PageUiPreferences();

      prefs.setProjectsFilterExpandedOverride(true);

      expect(prefs.projectsFilterExpandedOverride, isTrue);
    });

    test('updating one page key does not affect the others', () {
      final prefs = PageUiPreferences();

      prefs.setHistoryViewMode(HistoryViewMode.cards);
      prefs.setHistoryFilters(const HistoryFilters(taskIds: {'t1'}));

      expect(prefs.tasksViewMode, TaskViewMode.table);
      expect(prefs.tasksFilters.projectIds, isEmpty);
      expect(prefs.projectsViewMode, ProjectViewMode.table);
      expect(prefs.projectsFilters.activeCount, 0);
    });

    test('defaults to date-desc, name-asc, name-asc sort with no expanded override', () {
      final prefs = PageUiPreferences();

      expect(prefs.historySortField, HistorySortField.date);
      expect(prefs.historySortDirection, SortDirection.desc);
      expect(prefs.historySortExpandedOverride, isNull);

      expect(prefs.tasksSortField, TasksSortField.name);
      expect(prefs.tasksSortDirection, SortDirection.asc);
      expect(prefs.tasksSortExpandedOverride, isNull);

      expect(prefs.projectsSortField, ProjectsSortField.name);
      expect(prefs.projectsSortDirection, SortDirection.asc);
      expect(prefs.projectsSortExpandedOverride, isNull);
    });

    test('setHistorySortField/Direction/ExpandedOverride update and notify', () {
      final prefs = PageUiPreferences();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.setHistorySortField(HistorySortField.duration);
      prefs.setHistorySortDirection(SortDirection.asc);
      prefs.setHistorySortExpandedOverride(true);

      expect(prefs.historySortField, HistorySortField.duration);
      expect(prefs.historySortDirection, SortDirection.asc);
      expect(prefs.historySortExpandedOverride, isTrue);
      expect(notified, isTrue);
    });

    test('setTasksSortField/Direction/ExpandedOverride update and notify', () {
      final prefs = PageUiPreferences();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.setTasksSortField(TasksSortField.timeTracked);
      prefs.setTasksSortDirection(SortDirection.desc);
      prefs.setTasksSortExpandedOverride(true);

      expect(prefs.tasksSortField, TasksSortField.timeTracked);
      expect(prefs.tasksSortDirection, SortDirection.desc);
      expect(prefs.tasksSortExpandedOverride, isTrue);
      expect(notified, isTrue);
    });

    test('setProjectsSortField/Direction/ExpandedOverride update and notify', () {
      final prefs = PageUiPreferences();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.setProjectsSortField(ProjectsSortField.timeTracked);
      prefs.setProjectsSortDirection(SortDirection.desc);
      prefs.setProjectsSortExpandedOverride(true);

      expect(prefs.projectsSortField, ProjectsSortField.timeTracked);
      expect(prefs.projectsSortDirection, SortDirection.desc);
      expect(prefs.projectsSortExpandedOverride, isTrue);
      expect(notified, isTrue);
    });

    test('updating History sort does not affect Tasks/Projects sort', () {
      final prefs = PageUiPreferences();

      prefs.setHistorySortField(HistorySortField.duration);
      prefs.setHistorySortDirection(SortDirection.asc);

      expect(prefs.tasksSortField, TasksSortField.name);
      expect(prefs.tasksSortDirection, SortDirection.asc);
      expect(prefs.projectsSortField, ProjectsSortField.name);
      expect(prefs.projectsSortDirection, SortDirection.asc);
    });
  });
}
