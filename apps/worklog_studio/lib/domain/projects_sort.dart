import 'package:worklog_studio/domain/resolved_project.dart';
import 'package:worklog_studio/domain/sort_direction.dart';

enum ProjectsSortField { name, timeTracked }

List<ResolvedProject> applyProjectsSort(
  List<ResolvedProject> projects,
  ProjectsSortField field,
  SortDirection direction,
) {
  final sorted = List<ResolvedProject>.from(projects);
  final sign = direction == SortDirection.desc ? -1 : 1;
  final now = DateTime.now();

  switch (field) {
    case ProjectsSortField.name:
      sorted.sort(
        (a, b) => sign * a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    case ProjectsSortField.timeTracked:
      sorted.sort((a, b) => sign * a.duration(now).compareTo(b.duration(now)));
  }

  return sorted;
}
