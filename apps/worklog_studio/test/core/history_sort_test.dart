import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/history_sort.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';

ResolvedTimeEntry _entry({
  required String id,
  required DateTime startAt,
  DateTime? endAt,
  bool running = false,
  String taskTitle = 'Task',
  String projectName = 'Project',
}) {
  return ResolvedTimeEntry(
    entry: TimeEntry(
      id: id,
      taskId: 't-$id',
      projectId: 'p-$id',
      startAt: startAt,
      endAt: endAt,
      status: running ? TimeEntryStatus.running : TimeEntryStatus.stopped,
    ),
    task: Task(
      id: 't-$id',
      projectId: 'p-$id',
      title: taskTitle,
      description: '',
      status: TaskStatus.open,
      createdAt: startAt,
    ),
    project: Project(id: 'p-$id', name: projectName, description: '', createdAt: startAt),
  );
}

void main() {
  group('applyHistorySort', () {
    final jan1 = DateTime(2026, 1, 1, 9);
    final jan2 = DateTime(2026, 1, 2, 9);
    final jan3 = DateTime(2026, 1, 3, 9);

    test('date desc returns latest startAt first', () {
      final entries = [
        _entry(id: 'a', startAt: jan1),
        _entry(id: 'b', startAt: jan3),
        _entry(id: 'c', startAt: jan2),
      ];

      final result = applyHistorySort(entries, HistorySortField.date, SortDirection.desc);

      expect(result.map((e) => e.id), ['b', 'c', 'a']);
    });

    test('date asc returns earliest startAt first', () {
      final entries = [
        _entry(id: 'a', startAt: jan1),
        _entry(id: 'b', startAt: jan3),
        _entry(id: 'c', startAt: jan2),
      ];

      final result = applyHistorySort(entries, HistorySortField.date, SortDirection.asc);

      expect(result.map((e) => e.id), ['a', 'c', 'b']);
    });

    test('date sort pins running entries to the top regardless of direction', () {
      final entries = [
        _entry(id: 'a', startAt: jan1),
        _entry(id: 'running', startAt: jan1, running: true),
        _entry(id: 'b', startAt: jan3),
      ];

      final desc = applyHistorySort(entries, HistorySortField.date, SortDirection.desc);
      final asc = applyHistorySort(entries, HistorySortField.date, SortDirection.asc);

      expect(desc.first.id, 'running');
      expect(asc.first.id, 'running');
    });

    test('duration desc returns longest duration first, no running pin', () {
      final entries = [
        _entry(id: 'short', startAt: jan1, endAt: jan1.add(const Duration(minutes: 5))),
        _entry(id: 'long', startAt: jan1, endAt: jan1.add(const Duration(hours: 2))),
        _entry(id: 'medium', startAt: jan1, endAt: jan1.add(const Duration(hours: 1))),
      ];

      final result = applyHistorySort(entries, HistorySortField.duration, SortDirection.desc);

      expect(result.map((e) => e.id), ['long', 'medium', 'short']);
    });

    test('duration asc returns shortest duration first', () {
      final entries = [
        _entry(id: 'short', startAt: jan1, endAt: jan1.add(const Duration(minutes: 5))),
        _entry(id: 'long', startAt: jan1, endAt: jan1.add(const Duration(hours: 2))),
      ];

      final result = applyHistorySort(entries, HistorySortField.duration, SortDirection.asc);

      expect(result.map((e) => e.id), ['short', 'long']);
    });

    test('taskProjectName asc sorts case-insensitively by task title', () {
      final entries = [
        _entry(id: 'a', startAt: jan1, taskTitle: 'Zebra'),
        _entry(id: 'b', startAt: jan1, taskTitle: 'apple'),
        _entry(id: 'c', startAt: jan1, taskTitle: 'Mango'),
      ];

      final result = applyHistorySort(entries, HistorySortField.taskProjectName, SortDirection.asc);

      expect(result.map((e) => e.id), ['b', 'c', 'a']);
    });

    test('does not mutate the input list', () {
      final entries = [
        _entry(id: 'a', startAt: jan1),
        _entry(id: 'b', startAt: jan3),
      ];
      final original = List<ResolvedTimeEntry>.from(entries);

      applyHistorySort(entries, HistorySortField.date, SortDirection.asc);

      expect(entries.map((e) => e.id), original.map((e) => e.id));
    });
  });
}
