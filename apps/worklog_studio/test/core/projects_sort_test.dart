import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/projects_sort.dart';
import 'package:worklog_studio/domain/resolved_project.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/domain/time_entry.dart';

ResolvedProject _project({
  required String id,
  required String name,
  Duration tracked = Duration.zero,
}) {
  final start = DateTime(2026, 1, 1);
  return ResolvedProject(
    project: Project(id: id, name: name, description: '', createdAt: start),
    timeEntries: tracked == Duration.zero
        ? const []
        : [
            TimeEntry(
              id: 'te-$id',
              taskId: 't1',
              projectId: id,
              startAt: start,
              endAt: start.add(tracked),
              status: TimeEntryStatus.stopped,
            ),
          ],
  );
}

void main() {
  group('applyProjectsSort', () {
    test('name asc sorts case-insensitively', () {
      final projects = [
        _project(id: 'a', name: 'Zebra'),
        _project(id: 'b', name: 'apple'),
        _project(id: 'c', name: 'Mango'),
      ];

      final result = applyProjectsSort(projects, ProjectsSortField.name, SortDirection.asc);

      expect(result.map((p) => p.id), ['b', 'c', 'a']);
    });

    test('name desc reverses the order', () {
      final projects = [
        _project(id: 'a', name: 'Zebra'),
        _project(id: 'b', name: 'apple'),
      ];

      final result = applyProjectsSort(projects, ProjectsSortField.name, SortDirection.desc);

      expect(result.map((p) => p.id), ['a', 'b']);
    });

    test('timeTracked desc returns most-tracked first', () {
      final projects = [
        _project(id: 'short', name: 'A', tracked: const Duration(minutes: 10)),
        _project(id: 'long', name: 'B', tracked: const Duration(hours: 3)),
        _project(id: 'none', name: 'C'),
      ];

      final result = applyProjectsSort(projects, ProjectsSortField.timeTracked, SortDirection.desc);

      expect(result.map((p) => p.id), ['long', 'short', 'none']);
    });

    test('does not mutate the input list', () {
      final projects = [_project(id: 'a', name: 'Zebra'), _project(id: 'b', name: 'apple')];
      final originalOrder = projects.map((p) => p.id).toList();

      applyProjectsSort(projects, ProjectsSortField.name, SortDirection.asc);

      expect(projects.map((p) => p.id), originalOrder);
    });
  });
}
