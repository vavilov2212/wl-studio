import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/feature/tasks/presentation/components/task_list.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/page_ui_preferences.dart';

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
    final prefs = context.watch<PageUiPreferences>();
    final drawer = context.watch<DrawerHostController>();
    final selectedTask =
        drawer.kind == DrawerEntityKind.task ? drawer.task : null;
    final isFilterExpanded =
        prefs.tasksFilterExpandedOverride ?? prefs.tasksFilters.isActive;
    final isSortExpanded = prefs.tasksSortExpandedOverride ?? false;

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
      sortField: prefs.tasksSortField,
      sortDirection: prefs.tasksSortDirection,
      onSortFieldChanged: (field) =>
          context.read<PageUiPreferences>().setTasksSortField(field),
      onSortDirectionChanged: (direction) =>
          context.read<PageUiPreferences>().setTasksSortDirection(direction),
      isSortExpanded: isSortExpanded,
      onSortExpandedToggle: () => context
          .read<PageUiPreferences>()
          .setTasksSortExpandedOverride(!isSortExpanded),
    );
  }
}
