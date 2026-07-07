import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/domain/resolved_task.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/tasks_filters.dart';
import 'package:worklog_studio/domain/tasks_sort.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/tasks/presentation/components/task_table.dart';
import 'package:worklog_studio/feature/tasks/presentation/components/tasks_card.dart';
import 'package:worklog_studio/feature/tasks/presentation/components/tasks_filter_bar.dart';
import 'package:worklog_studio/feature/tasks/presentation/components/tasks_sort_bar.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

enum TaskViewMode { cards, table }

class TaskList extends StatelessWidget {
  final List<ResolvedTask> tasks;
  final Task? selectedTask;
  final GlobalKey? selectedRowKey;
  final ValueChanged<Task> onTaskSelected;
  final VoidCallback onCreateTask;
  final TaskViewMode viewMode;
  final ValueChanged<TaskViewMode> onViewModeChanged;
  final TasksFilters filters;
  final ValueChanged<TasksFilters> onFiltersChanged;
  final bool isFilterExpanded;
  final VoidCallback onFilterExpandedToggle;
  final TasksSortField sortField;
  final SortDirection sortDirection;
  final ValueChanged<TasksSortField> onSortFieldChanged;
  final ValueChanged<SortDirection> onSortDirectionChanged;
  final bool isSortExpanded;
  final VoidCallback onSortExpandedToggle;

  const TaskList({
    super.key,
    required this.tasks,
    required this.selectedTask,
    this.selectedRowKey,
    required this.onTaskSelected,
    required this.onCreateTask,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.filters,
    required this.onFiltersChanged,
    required this.isFilterExpanded,
    required this.onFilterExpandedToggle,
    required this.sortField,
    required this.sortDirection,
    required this.onSortFieldChanged,
    required this.onSortDirectionChanged,
    required this.isSortExpanded,
    required this.onSortExpandedToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Padding(
      padding: EdgeInsets.all(theme.spacings.x2l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Current Tasks', style: theme.commonTextStyles.h3),
              Row(
                spacing: theme.spacings.md,
                children: [
                  SegmentedToggle<TaskViewMode>(
                    value: viewMode,
                    onChanged: onViewModeChanged,
                    options: const [
                      SegmentedToggleOption(
                        value: TaskViewMode.cards,
                        icon: Icons.grid_view_rounded,
                      ),
                      SegmentedToggleOption(
                        value: TaskViewMode.table,
                        icon: Icons.table_rows_rounded,
                      ),
                    ],
                  ),
                  PrimaryButton(
                    title: 'New Task',
                    leftIcon: WorklogStudioAssets.vectors.plus24Svg,
                    size: ButtonSize.sm,
                    onTap: onCreateTask,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: theme.spacings.lg),
          TableToolbar(
            isFilterExpanded: isFilterExpanded,
            onFilterTap: onFilterExpandedToggle,
            activeFilterCount: filters.activeCount,
            isSortExpanded: isSortExpanded,
            onSortTap: onSortExpandedToggle,
          ),
          if (isSortExpanded) ...[
            SizedBox(height: theme.spacings.sm),
            TasksSortBar(
              field: sortField,
              direction: sortDirection,
              onFieldChanged: onSortFieldChanged,
              onDirectionChanged: onSortDirectionChanged,
            ),
          ],
          if (isFilterExpanded) ...[
            SizedBox(height: theme.spacings.sm),
            Builder(
              builder: (context) {
                final resolver = context.watch<EntityResolver>();
                final projectOptions = resolver
                    .getResolvedProjects()
                    .map((p) {
                      final colors = BadgeUtils.getBadgeColor(p.id);
                      return SelectOption(
                        value: p.id,
                        label: p.name,
                        leading: WsInitialBadge(
                          initials: BadgeUtils.getProjectInitials(p.name),
                          backgroundColor: colors.$1,
                          textColor: colors.$2,
                          size: WsInitialBadgeSize.small,
                        ),
                      );
                    })
                    .toList();
                return TasksFilterBar(
                  filters: filters,
                  onChanged: onFiltersChanged,
                  projectOptions: projectOptions,
                );
              },
            ),
          ],
          SizedBox(height: theme.spacings.x2l),
          Expanded(
            child: SingleChildScrollView(
              child: () {
                final filteredTasks = applyTasksSort(
                  applyTasksFilters(tasks, filters),
                  sortField,
                  sortDirection,
                );
                return viewMode == TaskViewMode.table
                  ? WsTable<ResolvedTask>(
                      data: filteredTasks,
                      selectedItem: filteredTasks.firstWhereOrNull(
                        (e) => e.id == selectedTask?.id,
                      ),
                      rowKeyBuilder: (item) =>
                          item.id == selectedTask?.id ? selectedRowKey : null,
                      onRowTap: (item) => onTaskSelected(item.task),
                      isSelected: (item, selected) => item.id == selected?.id,
                      columns: getTaskTableColumns(theme),
                    )
                  : Column(
                      spacing: theme.spacings.md,
                      children: filteredTasks.map((task) {
                        final isSelected = selectedTask?.id == task.id;
                        return TaskCard(
                          key: isSelected ? selectedRowKey : null,
                          task: task,
                          isSelected: isSelected,
                          onTap: () => onTaskSelected(task.task),
                        );
                      }).toList(),
                    );
              }(),
            ),
          ),
        ],
      ),
    );
  }
}
