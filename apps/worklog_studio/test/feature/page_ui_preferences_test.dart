import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/history_filters.dart';
import 'package:worklog_studio/domain/projects_filters.dart';
import 'package:worklog_studio/domain/tasks_filters.dart';
import 'package:worklog_studio/feature/history/presentation/history_page.dart';
import 'package:worklog_studio/feature/projects/presentation/projects_page.dart';
import 'package:worklog_studio/feature/tasks/presentation/tasks_page.dart';
import 'package:worklog_studio/state/page_ui_preferences.dart';

void main() {
  group('PageUiPreferences', () {
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
  });
}
