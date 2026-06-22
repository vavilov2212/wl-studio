import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/history_filters.dart';

class HistoryFilterBar extends StatelessWidget {
  final HistoryFilters filters;
  final ValueChanged<HistoryFilters> onChanged;
  final List<SelectOption<String>> taskOptions;
  final List<SelectOption<String>> projectOptions;

  const HistoryFilterBar({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.taskOptions,
    required this.projectOptions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ClearableFilterPill(
          isActive: filters.taskIds.isNotEmpty,
          onClear: () => onChanged(
            HistoryFilters(
              taskIds: const {},
              projectIds: filters.projectIds,
              dateFrom: filters.dateFrom,
              dateTo: filters.dateTo,
            ),
          ),
          child: SizedBox(
            width: 160,
            child: MultiSelect<String>(
              value: filters.taskIds.toList(),
              onChanged: (ids) => onChanged(
                HistoryFilters(
                  taskIds: ids.toSet(),
                  projectIds: filters.projectIds,
                  dateFrom: filters.dateFrom,
                  dateTo: filters.dateTo,
                ),
              ),
              options: taskOptions,
              placeholder: 'Task',
              searchable: true,
            ),
          ),
        ),
        SizedBox(width: theme.spacings.sm),
        ClearableFilterPill(
          isActive: filters.projectIds.isNotEmpty,
          onClear: () => onChanged(
            HistoryFilters(
              taskIds: filters.taskIds,
              projectIds: const {},
              dateFrom: filters.dateFrom,
              dateTo: filters.dateTo,
            ),
          ),
          child: SizedBox(
            width: 160,
            child: MultiSelect<String>(
              value: filters.projectIds.toList(),
              onChanged: (ids) => onChanged(
                HistoryFilters(
                  taskIds: filters.taskIds,
                  projectIds: ids.toSet(),
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
          isActive: filters.dateFrom != null,
          onClear: () => onChanged(
            HistoryFilters(taskIds: filters.taskIds, projectIds: filters.projectIds),
          ),
          child: SizedBox(
            width: 160,
            child: DateRangeButton(
              value: filters.dateFrom != null
                  ? DateTimeRange(start: filters.dateFrom!, end: filters.dateTo!)
                  : null,
              onChanged: (range) => onChanged(
                HistoryFilters(
                  taskIds: filters.taskIds,
                  projectIds: filters.projectIds,
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
            onPressed: () => onChanged(const HistoryFilters()),
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
