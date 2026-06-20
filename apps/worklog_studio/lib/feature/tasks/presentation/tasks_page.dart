import 'package:flutter/material.dart' hide DrawerControllerState;
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/resolved_task.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';
import 'components/tasks_card.dart';
import 'components/tasks_drawer.dart';
import 'package:worklog_studio/feature/common/presentation/drawer_controller_state.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'components/task_actions_cell.dart';

enum TaskViewMode { cards, table }

class TasksScreen extends StatefulWidget {
  final String? initialSelectedTaskId;

  const TasksScreen({super.key, this.initialSelectedTaskId});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  DrawerControllerState<Task> _drawerState = DrawerControllerState.closed();
  TaskViewMode _viewMode = TaskViewMode.table;
  final GlobalKey _selectedRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedTaskId != null) {
      _selectTaskById(widget.initialSelectedTaskId!);
    }
  }

  @override
  void didUpdateWidget(covariant TasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedTaskId != null &&
        widget.initialSelectedTaskId != oldWidget.initialSelectedTaskId) {
      _selectTaskById(widget.initialSelectedTaskId!);
    }
  }

  void _selectTaskById(String taskId) {
    final resolvedTask = context
        .read<EntityResolver>()
        .getResolvedTasks()
        .firstWhereOrNull((t) => t.id == taskId);
    if (resolvedTask != null) {
      setState(() {
        _drawerState = DrawerControllerState.edit(resolvedTask.task);
      });
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
    setState(() {
      if (_drawerState.state == DrawerState.edit &&
          _drawerState.entity?.id == task.id) {
        _drawerState = DrawerControllerState.closed();
      } else {
        _drawerState = DrawerControllerState.edit(task);
      }
    });
  }

  void _handleCreateTask() {
    setState(() {
      _drawerState = DrawerControllerState.create();
    });
  }

  void _closePanel() {
    setState(() {
      _drawerState = DrawerControllerState.closed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolver = context.watch<EntityResolver>();
    final resolvedTasks = resolver.getResolvedTasks();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: TaskList(
            tasks: resolvedTasks,
            selectedTask: _drawerState.entity,
            selectedRowKey: _selectedRowKey,
            onTaskSelected: _handleTaskSelected,
            onCreateTask: _handleCreateTask,
            viewMode: _viewMode,
            onViewModeChanged: (mode) => setState(() => _viewMode = mode),
          ),
        ),
        TaskDrawer(
          task: _drawerState.entity,
          isOpen: _drawerState.isOpen,
          onClose: _closePanel,
        ),
      ],
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

  const TaskList({
    super.key,
    required this.tasks,
    required this.selectedTask,
    this.selectedRowKey,
    required this.onTaskSelected,
    required this.onCreateTask,
    required this.viewMode,
    required this.onViewModeChanged,
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
          SizedBox(height: theme.spacings.x2l),
          Expanded(
            child: SingleChildScrollView(
              child: viewMode == TaskViewMode.table
                  ? WsTable<ResolvedTask>(
                      data: tasks,
                      selectedItem: tasks.firstWhereOrNull(
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
                      children: tasks.map((task) {
                        final isSelected = selectedTask?.id == task.id;
                        return TaskCard(
                          key: isSelected ? selectedRowKey : null,
                          task: task,
                          isSelected: isSelected,
                          onTap: () => onTaskSelected(task.task),
                        );
                      }).toList(),
                    ),
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

