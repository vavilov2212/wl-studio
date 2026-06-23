import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/history_filters.dart';

class HistoryFilterBar extends StatefulWidget {
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
  State<HistoryFilterBar> createState() => _HistoryFilterBarState();
}

class _HistoryFilterBarState extends State<HistoryFilterBar> {
  final ScrollController _scrollController = ScrollController();

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
                    width: 140,
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
                      options: widget.taskOptions,
                      placeholder: 'Task',
                      searchable: true,
                      size: ControlSize.xs,
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
                    width: 140,
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
                      options: widget.projectOptions,
                      placeholder: 'Project',
                      searchable: true,
                      size: ControlSize.xs,
                    ),
                  ),
                ),
                SizedBox(width: theme.spacings.sm),
                ClearableFilterPill(
                  isActive: filters.dateFrom != null,
                  onClear: () => onChanged(
                    HistoryFilters(
                      taskIds: filters.taskIds,
                      projectIds: filters.projectIds,
                    ),
                  ),
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
                        HistoryFilters(
                          taskIds: filters.taskIds,
                          projectIds: filters.projectIds,
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
            ),
          ),
        ),
      ),
    );
  }
}
