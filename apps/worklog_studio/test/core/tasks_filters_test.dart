import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/resolved_task.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/tasks_filters.dart';

ResolvedTask _task({
  required String id,
  required String projectId,
  required TaskStatus status,
  required DateTime createdAt,
}) {
  return ResolvedTask(
    task: Task(
      id: id,
      projectId: projectId,
      title: 'Task $id',
      description: '',
      status: status,
      createdAt: createdAt,
    ),
    project: Project(
      id: projectId,
      name: 'Project $projectId',
      description: '',
      createdAt: createdAt,
    ),
  );
}

void main() {
  group('TasksFilters', () {
    test('isActive and activeCount are false/0 when nothing is set', () {
      const filters = TasksFilters();
      expect(filters.isActive, isFalse);
      expect(filters.activeCount, 0);
    });

    test('activeCount sums each active dimension independently', () {
      final filters = TasksFilters(
        projectIds: {'p1'},
        statuses: {TaskStatus.open},
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 1, 31),
      );
      expect(filters.activeCount, 3);
    });
  });

  group('applyTasksFilters', () {
    final jan1 = DateTime(2026, 1, 1);
    final jan15 = DateTime(2026, 1, 15);
    final feb1 = DateTime(2026, 2, 1);

    final tasks = [
      _task(id: 't1', projectId: 'p1', status: TaskStatus.open, createdAt: jan1),
      _task(id: 't2', projectId: 'p1', status: TaskStatus.done, createdAt: jan15),
      _task(id: 't3', projectId: 'p2', status: TaskStatus.open, createdAt: feb1),
    ];

    test('returns all tasks when no filters are set', () {
      final result = applyTasksFilters(tasks, const TasksFilters());
      expect(result.length, 3);
    });

    test('filters by project id', () {
      final result = applyTasksFilters(
        tasks,
        const TasksFilters(projectIds: {'p1'}),
      );
      expect(result.map((t) => t.id), ['t1', 't2']);
    });

    test('filters by multiple statuses using OR logic', () {
      final result = applyTasksFilters(
        tasks,
        const TasksFilters(statuses: {TaskStatus.open}),
      );
      expect(result.map((t) => t.id), ['t1', 't3']);
    });

    test('filters by date range inclusive of both endpoints', () {
      final result = applyTasksFilters(
        tasks,
        TasksFilters(dateFrom: jan1, dateTo: jan15),
      );
      expect(result.map((t) => t.id), ['t1', 't2']);
    });

    test('combines project, status, and date filters with AND logic', () {
      final result = applyTasksFilters(
        tasks,
        TasksFilters(
          projectIds: {'p1'},
          statuses: {TaskStatus.open},
          dateFrom: jan1,
          dateTo: jan1,
        ),
      );
      expect(result.map((t) => t.id), ['t1']);
    });
  });
}
