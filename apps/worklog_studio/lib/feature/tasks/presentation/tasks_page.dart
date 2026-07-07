import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/feature/tasks/bloc/tasks_bloc.dart';
import 'package:worklog_studio/feature/tasks/presentation/components/task_list.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
import 'package:worklog_studio/state/entity_resolver.dart';

export 'package:worklog_studio/feature/tasks/presentation/components/task_list.dart'
    show TaskViewMode;

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
    final drawer = context.watch<DrawerHostController>();
    final selectedTask =
        drawer.kind == DrawerEntityKind.task ? drawer.task : null;

    return BlocBuilder<TasksBloc, TasksState>(
      builder: (context, tasksState) {
        final isFilterExpanded =
            tasksState.filterExpandedOverride ?? tasksState.filters.isActive;
        final isSortExpanded = tasksState.sortExpanded;

        return TaskList(
          tasks: resolvedTasks,
          selectedTask: selectedTask,
          selectedRowKey: _selectedRowKey,
          onTaskSelected: _handleTaskSelected,
          onCreateTask: _handleCreateTask,
          viewMode: tasksState.viewMode,
          onViewModeChanged: (mode) =>
              context.read<TasksBloc>().add(TasksViewModeChanged(mode)),
          filters: tasksState.filters,
          onFiltersChanged: (f) =>
              context.read<TasksBloc>().add(TasksFilterChanged(f)),
          isFilterExpanded: isFilterExpanded,
          onFilterExpandedToggle: () => context.read<TasksBloc>().add(
            TasksFilterExpandedOverrideSet(!isFilterExpanded),
          ),
          sortField: tasksState.sortField,
          sortDirection: tasksState.sortDirection,
          onSortFieldChanged: (field) =>
              context.read<TasksBloc>().add(TasksSortFieldChanged(field)),
          onSortDirectionChanged: (direction) =>
              context.read<TasksBloc>().add(TasksSortDirectionChanged(direction)),
          isSortExpanded: isSortExpanded,
          onSortExpandedToggle: () => context.read<TasksBloc>().add(
            TasksSortExpandedSet(!isSortExpanded),
          ),
        );
      },
    );
  }
}
