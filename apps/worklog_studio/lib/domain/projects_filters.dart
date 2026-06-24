import 'project.dart';
import 'resolved_project.dart';

class ProjectsFilters {
  final Set<ProjectStatus> statuses;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const ProjectsFilters({
    this.statuses = const {},
    this.dateFrom,
    this.dateTo,
  });

  bool get isActive => statuses.isNotEmpty || dateFrom != null;

  int get activeCount =>
      (statuses.isNotEmpty ? 1 : 0) + (dateFrom != null ? 1 : 0);
}

List<ResolvedProject> applyProjectsFilters(
  List<ResolvedProject> projects,
  ProjectsFilters filters,
) {
  return projects.where((project) {
    if (filters.statuses.isNotEmpty &&
        !filters.statuses.contains(project.status)) {
      return false;
    }
    if (filters.dateFrom != null && filters.dateTo != null) {
      final day = DateTime(
        project.createdAt.year,
        project.createdAt.month,
        project.createdAt.day,
      );
      final from = DateTime(
        filters.dateFrom!.year,
        filters.dateFrom!.month,
        filters.dateFrom!.day,
      );
      final to = DateTime(
        filters.dateTo!.year,
        filters.dateTo!.month,
        filters.dateTo!.day,
      );
      if (day.isBefore(from) || day.isAfter(to)) return false;
    }
    return true;
  }).toList();
}
