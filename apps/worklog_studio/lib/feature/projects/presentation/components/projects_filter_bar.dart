import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/projects_filters.dart';

class ProjectsFilterBar extends StatefulWidget {
  final ProjectsFilters filters;
  final ValueChanged<ProjectsFilters> onChanged;

  const ProjectsFilterBar({
    super.key,
    required this.filters,
    required this.onChanged,
  });

  @override
  State<ProjectsFilterBar> createState() => _ProjectsFilterBarState();
}

class _ProjectsFilterBarState extends State<ProjectsFilterBar> {
  final ScrollController _scrollController = ScrollController();

  static const _statusOptions = [
    SelectOption(value: ProjectStatus.open, label: 'Open'),
    SelectOption(value: ProjectStatus.done, label: 'Done'),
    SelectOption(value: ProjectStatus.archived, label: 'Archived'),
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final filters = widget.filters;
    final onChanged = widget.onChanged;

    return Align(
      alignment: Alignment.centerRight,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Padding(
            padding: EdgeInsets.only(top: theme.spacings.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
                    width: 140,
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
                      size: ControlSize.xs,
                    ),
                  ),
                ),
                SizedBox(width: theme.spacings.sm),
                ClearableFilterPill(
                  isActive: filters.dateFrom != null,
                  onClear: () =>
                      onChanged(ProjectsFilters(statuses: filters.statuses)),
                  child: SizedBox(
                    width: 140,
                    child: DateRangeButton(
                      value: filters.dateFrom != null
                          ? DateTimeRange(
                              start: filters.dateFrom!,
                              end: filters.dateTo!,
                            )
                          : null,
                      onChanged: (range) => onChanged(
                        ProjectsFilters(
                          statuses: filters.statuses,
                          dateFrom: range?.start,
                          dateTo: range?.end,
                        ),
                      ),
                      placeholder: 'Date',
                      size: ControlSize.xs,
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
            ),
          ),
        ),
      ),
    );
  }
}
