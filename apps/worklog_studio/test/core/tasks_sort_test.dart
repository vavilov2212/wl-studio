import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/tasks_sort.dart';
import 'package:worklog_studio/domain/resolved_task.dart';
import 'package:worklog_studio/domain/time_entry.dart';

ResolvedTask _task({
  required String id,
  required String title,
  Duration tracked = Duration.zero,
}) {
  final start = DateTime(2026, 1, 1);
  return ResolvedTask(
    task: Task(
      id: id,
      projectId: 'p1',
      title: title,
      description: '',
      status: TaskStatus.open,
      createdAt: start,
    ),
    timeEntries: tracked == Duration.zero
        ? const []
        : [
            TimeEntry(
              id: 'te-$id',
              taskId: id,
              projectId: 'p1',
              startAt: start,
              endAt: start.add(tracked),
              status: TimeEntryStatus.stopped,
            ),
          ],
  );
}

void main() {
  group('applyTasksSort', () {
    test('name asc sorts case-insensitively', () {
      final tasks = [
        _task(id: 'a', title: 'Zebra'),
        _task(id: 'b', title: 'apple'),
        _task(id: 'c', title: 'Mango'),
      ];

      final result = applyTasksSort(tasks, TasksSortField.name, SortDirection.asc);

      expect(result.map((t) => t.id), ['b', 'c', 'a']);
    });

    test('name desc reverses the order', () {
      final tasks = [
        _task(id: 'a', title: 'Zebra'),
        _task(id: 'b', title: 'apple'),
      ];

      final result = applyTasksSort(tasks, TasksSortField.name, SortDirection.desc);

      expect(result.map((t) => t.id), ['a', 'b']);
    });

    test('timeTracked desc returns most-tracked first', () {
      final tasks = [
        _task(id: 'short', title: 'A', tracked: const Duration(minutes: 10)),
        _task(id: 'long', title: 'B', tracked: const Duration(hours: 3)),
        _task(id: 'none', title: 'C'),
      ];

      final result = applyTasksSort(tasks, TasksSortField.timeTracked, SortDirection.desc);

      expect(result.map((t) => t.id), ['long', 'short', 'none']);
    });

    test('does not mutate the input list', () {
      final tasks = [_task(id: 'a', title: 'Zebra'), _task(id: 'b', title: 'apple')];
      final originalOrder = tasks.map((t) => t.id).toList();

      applyTasksSort(tasks, TasksSortField.name, SortDirection.asc);

      expect(tasks.map((t) => t.id), originalOrder);
    });
  });
}
