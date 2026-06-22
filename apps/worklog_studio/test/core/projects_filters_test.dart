import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/projects_filters.dart';
import 'package:worklog_studio/domain/resolved_project.dart';

ResolvedProject _project({
  required String id,
  required ProjectStatus status,
  required DateTime createdAt,
}) {
  return ResolvedProject(
    project: Project(
      id: id,
      name: 'Project $id',
      description: '',
      createdAt: createdAt,
      status: status,
    ),
  );
}

void main() {
  group('ProjectsFilters', () {
    test('isActive and activeCount are false/0 when nothing is set', () {
      const filters = ProjectsFilters();
      expect(filters.isActive, isFalse);
      expect(filters.activeCount, 0);
    });

    test('activeCount sums each active dimension independently', () {
      final filters = ProjectsFilters(
        statuses: {ProjectStatus.open},
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 1, 31),
      );
      expect(filters.activeCount, 2);
    });
  });

  group('applyProjectsFilters', () {
    final jan1 = DateTime(2026, 1, 1);
    final jan15 = DateTime(2026, 1, 15);
    final feb1 = DateTime(2026, 2, 1);

    final projects = [
      _project(id: 'p1', status: ProjectStatus.open, createdAt: jan1),
      _project(id: 'p2', status: ProjectStatus.done, createdAt: jan15),
      _project(id: 'p3', status: ProjectStatus.open, createdAt: feb1),
    ];

    test('returns all projects when no filters are set', () {
      final result = applyProjectsFilters(projects, const ProjectsFilters());
      expect(result.length, 3);
    });

    test('filters by multiple statuses using OR logic', () {
      final result = applyProjectsFilters(
        projects,
        const ProjectsFilters(statuses: {ProjectStatus.open}),
      );
      expect(result.map((p) => p.id), ['p1', 'p3']);
    });

    test('filters by date range inclusive of both endpoints', () {
      final result = applyProjectsFilters(
        projects,
        ProjectsFilters(dateFrom: jan1, dateTo: jan15),
      );
      expect(result.map((p) => p.id), ['p1', 'p2']);
    });

    test('combines status and date filters with AND logic', () {
      final result = applyProjectsFilters(
        projects,
        ProjectsFilters(
          statuses: {ProjectStatus.open},
          dateFrom: jan1,
          dateTo: jan1,
        ),
      );
      expect(result.map((p) => p.id), ['p1']);
    });
  });
}
