import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/resolved_task.dart';
import 'package:worklog_studio/domain/tasks_filters.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/page_ui_preferences.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';
import 'components/tasks_card.dart';
import 'components/tasks_filter_bar.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'components/task_actions_cell.dart';

enum TaskViewMode { cards, table }

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final GlobalKey _selectedRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final drawer = context.read<DrawerHostController>();
    if (drawer.kind == DrawerEntityKind.task && drawer.task != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final rowContext = _selectedRowKey.currentContext;
        if (rowContext != null) {
          Scrollable.ensureVisible(
            rowContext,
            duration: const Duration(milliseconds: 300),
            alignment: 0.5,
          );
        }
      });
    }
  }

  void _handleTaskSelected(Task task) {
    final drawer = context.read<DrawerHostController>();
    if (drawer.kind == DrawerEntityKind.task && drawer.task?.id == task.id) {
      drawer.close();
    } else {
      drawer.openTaskEdit(task);
    }
  }

  void _handleCreateTask() {
    context.read<DrawerHostController>().openTaskCreate();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedTasks = context.watch<EntityResolver>().getResolvedTasks();
    final prefs = context.watch<PageUiPreferences>();
    final drawer = context.watch<DrawerHostController>();
    final selectedTask =
        drawer.kind == DrawerEntityKind.task ? drawer.task : null;
    final isFilterExpanded =
        prefs.tasksFilterExpandedOverride ?? prefs.tasksFilters.isActive;

    return TaskList(
      tasks: resolvedTasks,
      selectedTask: selectedTask,
      selectedRowKey: _selectedRowKey,
      onTaskSelected: _handleTaskSelected,
      onCreateTask: _handleCreateTask,
      viewMode: prefs.tasksViewMode,
      onViewModeChanged: (mode) =>
          context.read<PageUiPreferences>().setTasksViewMode(mode),
      filters: prefs.tasksFilters,
      onFiltersChanged: (f) =>
          context.read<PageUiPreferences>().setTasksFilters(f),
      isFilterExpanded: isFilterExpanded,
      onFilterExpandedToggle: () => context
          .read<PageUiPreferences>()
          .setTasksFilterExpandedOverride(!isFilterExpanded),
    );
  }
}

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
          ),
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
                final filteredTasks = applyTasksFilters(tasks, filters);
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
                      columns: _getTableColumns(theme),
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

  List<WsTableColumn<ResolvedTask>> _getTableColumns(AppThemeExtension theme) {
    return [
      WsTableColumn(
        title: 'Task & Project',
        flex: 3,
        builder: (context, item, isHovered) {
          final palette = theme.colorsPalette;
          final initials = BadgeUtils.getTaskInitials(
            item.title,
            item.projectName,
          );
          final colors = BadgeUtils.getBadgeColor(item.id);

          return Row(
            children: [
              WsInitialBadge(
                initials: initials,
                backgroundColor: colors.$1,
                textColor: colors.$2,
                size: WsInitialBadgeSize.small,
              ),
              SizedBox(width: theme.spacings.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.commonTextStyles.labelMedium,
                    ),
                    if (item.projectName.isNotEmpty)
                      Text(
                        item.projectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.commonTextStyles.caption.copyWith(
                          color: palette.text.secondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      WsTableColumn(
        title: 'Description',
        flex: 8,
        builder: (context, item, isHovered) {
          final palette = theme.colorsPalette;
          return Text(
            item.task.description.isEmpty
                ? 'No description'
                : item.task.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: theme.commonTextStyles.body2.copyWith(
              color: item.task.description.isEmpty
                  ? palette.text.secondary.withValues(alpha: 0.5)
                  : palette.text.secondary,
            ),
          );
        },
      ),
      WsTableColumn(
        title: 'Time tracked',
        flex: 2,
        builder: (context, item, isHovered) {
          final isActive = context.select<TimeTrackerBloc, bool>(
            (bloc) => bloc.state.activeEntryOrNull?.taskId == item.id,
          );

          if (isActive) {
            return LiveDurationText(
              durationBuilder: (now) => item.duration(now),
              style: theme.commonTextStyles.labelMedium.copyWith(
                color: theme.colorsPalette.accent.primary,
              ),
            );
          }

          final duration = item.duration(DateTime.now());
          return Text(
            _formatExactDuration(duration),
            style: theme.commonTextStyles.labelMedium,
          );
        },
      ),
      WsTableColumn(
        title: 'Status',
        flex: 1,
        builder: (context, item, isHovered) {
          final isActive = context.select<TimeTrackerBloc, bool>(
            (bloc) => bloc.state.activeEntryOrNull?.taskId == item.id,
          );

          if (isActive) {
            return const Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(
                status: BadgeStatus.inProgress,
                label: 'RUNNING',
              ),
            );
          }

          return Align(
            alignment: Alignment.centerLeft,
            child: StatusBadge(
              status: _getBadgeStatus(item.status),
              label: item.status.name.toUpperCase(),
            ),
          );
        },
      ),
      WsTableColumn(
        title: 'Actions',
        alignment: Alignment.centerRight,

        flex: 1,
        builder: (context, item, _) {
          return TaskActionsCell(task: item);
        },
      ),
    ];
  }

  BadgeStatus _getBadgeStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return BadgeStatus.inProgress;
      case TaskStatus.done:
        return BadgeStatus.ready;
      case TaskStatus.archived:
        return BadgeStatus.done;
    }
  }

  String _formatExactDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

