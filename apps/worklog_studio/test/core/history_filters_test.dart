import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/history_filters.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';

ResolvedTimeEntry _entry({
  required String id,
  String? taskId,
  String? projectId,
  required DateTime startAt,
}) {
  return ResolvedTimeEntry(
    entry: TimeEntry(
      id: id,
      taskId: taskId,
      projectId: projectId,
      startAt: startAt,
      status: TimeEntryStatus.stopped,
    ),
    task: taskId != null
        ? Task(
            id: taskId,
            projectId: projectId ?? 'p0',
            title: 'Task $taskId',
            description: '',
            status: TaskStatus.open,
            createdAt: startAt,
          )
        : null,
    project: projectId != null
        ? Project(id: projectId, name: 'Project $projectId', description: '', createdAt: startAt)
        : null,
  );
}

void main() {
  group('HistoryFilters', () {
    test('isActive and activeCount are false/0 when nothing is set', () {
      const filters = HistoryFilters();
      expect(filters.isActive, isFalse);
      expect(filters.activeCount, 0);
    });

    test('activeCount sums each active dimension independently', () {
      final filters = HistoryFilters(
        taskIds: {'t1'},
        projectIds: {'p1'},
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 1, 31),
      );
      expect(filters.isActive, isTrue);
      expect(filters.activeCount, 3);
    });
  });

  group('applyHistoryFilters', () {
    final jan1 = DateTime(2026, 1, 1);
    final jan15 = DateTime(2026, 1, 15);
    final feb1 = DateTime(2026, 2, 1);

    final entries = [
      _entry(id: 'e1', taskId: 't1', projectId: 'p1', startAt: jan1),
      _entry(id: 'e2', taskId: 't2', projectId: 'p1', startAt: jan15),
      _entry(id: 'e3', taskId: 't1', projectId: 'p2', startAt: feb1),
      _entry(id: 'e4', startAt: jan15),
    ];

    test('returns all entries when no filters are set', () {
      final result = applyHistoryFilters(entries, const HistoryFilters());
      expect(result.length, 4);
    });

    test('filters by a single task id', () {
      final result = applyHistoryFilters(
        entries,
        const HistoryFilters(taskIds: {'t1'}),
      );
      expect(result.map((e) => e.id), ['e1', 'e3']);
    });

    test('filters by multiple task ids using OR logic', () {
      final result = applyHistoryFilters(
        entries,
        const HistoryFilters(taskIds: {'t1', 't2'}),
      );
      expect(result.map((e) => e.id), ['e1', 'e2', 'e3']);
    });

    test('filters by project id', () {
      final result = applyHistoryFilters(
        entries,
        const HistoryFilters(projectIds: {'p1'}),
      );
      expect(result.map((e) => e.id), ['e1', 'e2']);
    });

    test('filters by date range inclusive of both endpoints', () {
      final result = applyHistoryFilters(
        entries,
        HistoryFilters(dateFrom: jan1, dateTo: jan15),
      );
      expect(result.map((e) => e.id), ['e1', 'e2', 'e4']);
    });

    test('combines task, project, and date filters with AND logic', () {
      final result = applyHistoryFilters(
        entries,
        HistoryFilters(
          taskIds: {'t1'},
          projectIds: {'p1'},
          dateFrom: jan1,
          dateTo: jan1,
        ),
      );
      expect(result.map((e) => e.id), ['e1']);
    });

    test('entries with no task/project never match an active task or project filter', () {
      final result = applyHistoryFilters(
        entries,
        const HistoryFilters(taskIds: {'t1'}),
      );
      expect(result.any((e) => e.id == 'e4'), isFalse);
    });
  });
}
