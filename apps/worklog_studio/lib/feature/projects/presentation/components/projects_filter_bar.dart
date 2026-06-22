import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/projects_filters.dart';

class ProjectsFilterBar extends StatelessWidget {
  final ProjectsFilters filters;
  final ValueChanged<ProjectsFilters> onChanged;

  const ProjectsFilterBar({
    super.key,
    required this.filters,
    required this.onChanged,
  });

  static const _statusOptions = [
    SelectOption(value: ProjectStatus.open, label: 'Open'),
    SelectOption(value: ProjectStatus.done, label: 'Done'),
    SelectOption(value: ProjectStatus.archived, label: 'Archived'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ClearableFilterPill(
          isActive: filters.statuses.isNotEmpty,
          onClear: () => onChanged(
            ProjectsFilters(
              statuses: const {},
              dateFrom: filters.dateFrom,
              dateTo: filters.dateTo,
            ),
          ),
          child: SizedBox(
            width: 160,
            child: MultiSelect<ProjectStatus>(
              value: filters.statuses.toList(),
              onChanged: (statuses) => onChanged(
                ProjectsFilters(
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
          onClear: () => onChanged(ProjectsFilters(statuses: filters.statuses)),
          child: SizedBox(
            width: 160,
            child: DateRangeButton(
              value: filters.dateFrom != null
                  ? DateTimeRange(start: filters.dateFrom!, end: filters.dateTo!)
                  : null,
              onChanged: (range) => onChanged(
                ProjectsFilters(
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
            onPressed: () => onChanged(const ProjectsFilters()),
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
