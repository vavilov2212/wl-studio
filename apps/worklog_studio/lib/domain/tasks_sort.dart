import 'package:worklog_studio/domain/resolved_task.dart';
import 'package:worklog_studio/domain/sort_direction.dart';

enum TasksSortField { name, timeTracked }

List<ResolvedTask> applyTasksSort(
  List<ResolvedTask> tasks,
  TasksSortField field,
  SortDirection direction,
) {
  final sorted = List<ResolvedTask>.from(tasks);
  final sign = direction == SortDirection.desc ? -1 : 1;
  final now = DateTime.now();

  switch (field) {
    case TasksSortField.name:
      sorted.sort(
        (a, b) => sign * a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    case TasksSortField.timeTracked:
      sorted.sort((a, b) => sign * a.duration(now).compareTo(b.duration(now)));
  }

  return sorted;
}
