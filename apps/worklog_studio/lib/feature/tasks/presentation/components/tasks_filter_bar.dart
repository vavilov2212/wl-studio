import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/tasks_filters.dart';

class TasksFilterBar extends StatelessWidget {
  final TasksFilters filters;
  final ValueChanged<TasksFilters> onChanged;
  final List<SelectOption<String>> projectOptions;

  const TasksFilterBar({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.projectOptions,
  });

  static const _statusOptions = [
    SelectOption(value: TaskStatus.open, label: 'Open'),
    SelectOption(value: TaskStatus.done, label: 'Done'),
    SelectOption(value: TaskStatus.archived, label: 'Archived'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Row(
      children: [
        ClearableFilterPill(
          isActive: filters.projectIds.isNotEmpty,
          onClear: () => onChanged(
            TasksFilters(
              projectIds: const {},
              statuses: filters.statuses,
              dateFrom: filters.dateFrom,
              dateTo: filters.dateTo,
            ),
          ),
          child: SizedBox(
            width: 160,
            child: MultiSelect<String>(
              value: filters.projectIds.toList(),
              onChanged: (ids) => onChanged(
                TasksFilters(
                  projectIds: ids.toSet(),
                  statuses: filters.statuses,
                  dateFrom: filters.dateFrom,
                  dateTo: filters.dateTo,
                ),
              ),
              options: projectOptions,
              placeholder: 'Project',
              searchable: true,
            ),
          ),
        ),
        SizedBox(width: theme.spacings.sm),
        ClearableFilterPill(
          isActive: filters.statuses.isNotEmpty,
          onClear: () => onChanged(
            TasksFilters(
              projectIds: filters.projectIds,
              statuses: const {},
              dateFrom: filters.dateFrom,
              dateTo: filters.dateTo,
            ),
          ),
          child: SizedBox(
            width: 160,
            child: MultiSelect<TaskStatus>(
              value: filters.statuses.toList(),
              onChanged: (statuses) => onChanged(
                TasksFilters(
                  projectIds: filters.projectIds,
                  statuses: statuses.toSet(),
                  dateFrom: filters.dateFrom,
                  dateTo: filters.dateTo,
                ),
              ),
              options: _statusOptions,
              placeholder: 'Status',
            ),
          ),
        ),
        SizedBox(width: theme.spacings.sm),
        ClearableFilterPill(
          isActive: filters.dateFrom != null,
          onClear: () => onChanged(
            TasksFilters(projectIds: filters.projectIds, statuses: filters.statuses),
          ),
          child: SizedBox(
            width: 160,
            child: DateRangeButton(
              value: filters.dateFrom != null
                  ? DateTimeRange(start: filters.dateFrom!, end: filters.dateTo!)
                  : null,
              onChanged: (range) => onChanged(
                TasksFilters(
                  projectIds: filters.projectIds,
                  statuses: filters.statuses,
                  dateFrom: range?.start,
                  dateTo: range?.end,
                ),
              ),
              placeholder: 'Date',
            ),
          ),
        ),
        if (filters.isActive) ...[
          SizedBox(width: theme.spacings.sm),
          TextButton(
            onPressed: () => onChanged(const TasksFilters()),
            child: Text(
              'Reset all',
              style: theme.commonTextStyles.caption.copyWith(
                color: theme.colorsPalette.text.secondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
