import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/tasks_filters.dart';

class TasksFilterBar extends StatefulWidget {
  final TasksFilters filters;
  final ValueChanged<TasksFilters> onChanged;
  final List<SelectOption<String>> projectOptions;

  const TasksFilterBar({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.projectOptions,
  });

  @override
  State<TasksFilterBar> createState() => _TasksFilterBarState();
}

class _TasksFilterBarState extends State<TasksFilterBar> {
  final ScrollController _scrollController = ScrollController();

  static const _statusOptions = [
    SelectOption(value: TaskStatus.open, label: 'Open'),
    SelectOption(value: TaskStatus.done, label: 'Done'),
    SelectOption(value: TaskStatus.archived, label: 'Archived'),
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
          clipBehavior: Clip.none,
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
                    options: widget.projectOptions,
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
                  TasksFilters(
                    projectIds: filters.projectIds,
                    statuses: filters.statuses,
                  ),
                ),
                child: SizedBox(
                  width: 160,
                  child: DateRangeButton(
                    value: filters.dateFrom != null
                        ? DateTimeRange(
                            start: filters.dateFrom!,
                            end: filters.dateTo!,
                          )
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
          ),
        ),
      ),
    );
  }
}
