import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/feature/settings/settings_screen.dart';
import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/feature/home/presentation/home_page.dart';
import 'package:worklog_studio/feature/projects/presentation/projects_page.dart';
import 'package:worklog_studio/feature/tasks/presentation/tasks_page.dart';
import 'package:worklog_studio/feature/history/presentation/history_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/active_timer_text.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field_controller.dart';

import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio/core/services/desktop/desktop_service_registry.dart';
import 'dart:async';

enum AppRoute { dashboard, history, projects, tasks, settings }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppRoute _currentRoute = AppRoute.dashboard;
  StreamSubscription<String>? _navSub;

  @override
  void initState() {
    super.initState();
    _navSub = DesktopServiceRegistry.instance.navigationStream.listen((route) {
      if (route == 'history') {
        _onRouteSelected(AppRoute.history);
      } else if (route == 'tasks') {
        _onRouteSelected(AppRoute.tasks);
      } else if (route == 'projects') {
        _onRouteSelected(AppRoute.projects);
      }
    });
  }

  @override
  void dispose() {
    _navSub?.cancel();
    super.dispose();
  }

  void _onRouteSelected(AppRoute route) {
    setState(() {
      _currentRoute = route;
    });
  }

  Widget _buildActiveScreen() {
    return IndexedStack(
      index: _currentRoute.index,
      children: const [
        HomePage(title: 'Dashboard'),
        HistoryScreen(),
        ProjectsScreen(),
        TasksScreen(),
        SettingsScreen(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Scaffold(
      backgroundColor: palette.background.canvas,
      body: Row(
        children: [
          SidebarNavigation(
            currentRoute: _currentRoute,
            onRouteSelected: _onRouteSelected,
          ),
          Expanded(
            child: Column(
              children: [
                const TopAppBar(),
                Expanded(child: _buildActiveScreen()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TopAppBar extends StatelessWidget {
  const TopAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.background.surface,
        border: Border(bottom: BorderSide(color: palette.border.primary)),
      ),
      child: const GlobalTimeTrackerPanel(),
    );
  }
}

class GlobalTimeTrackerPanel extends StatefulWidget {
  const GlobalTimeTrackerPanel({super.key});

  @override
  State<GlobalTimeTrackerPanel> createState() => _GlobalTimeTrackerPanelState();
}

class _GlobalTimeTrackerPanelState extends State<GlobalTimeTrackerPanel> {
  final TextEditingController _commentController = TextEditingController();
  final InlineFieldController _projectFieldController = InlineFieldController();
  final InlineFieldController _taskFieldController = InlineFieldController();
  final InlineFieldController _commentFieldController = InlineFieldController();

  @override
  void dispose() {
    _commentController.dispose();
    _projectFieldController.dispose();
    _taskFieldController.dispose();
    _commentFieldController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final projectTaskState = context.read<ProjectTaskState>();

    return BlocListener<TimeTrackerBloc, TimeTrackerBlocState>(
      listenWhen: (previous, current) =>
          previous.activeEntryOrNull != current.activeEntryOrNull,
      listener: (context, state) {
        final activeEntry = state.activeEntryOrNull;
        if (activeEntry != null) {
          projectTaskState.updateDraft(
            projectId: activeEntry.projectId,
            taskId: activeEntry.taskId,
            comment: activeEntry.comment ?? '',
          );
          if (_commentController.text != (activeEntry.comment ?? '')) {
            _commentController.text = activeEntry.comment ?? '';
          }
        }
      },
      child: BlocBuilder<TimeTrackerBloc, TimeTrackerBlocState>(
        buildWhen: (previous, current) =>
            previous.isRunning != current.isRunning ||
            previous.activeEntryOrNull != current.activeEntryOrNull,
        builder: (context, state) {
          final isRunning = state.isRunning;
          final draftProjectId = context.select<ProjectTaskState, String?>(
            (s) => s.draftProjectId,
          );
          final draftTaskId = context.select<ProjectTaskState, String?>(
            (s) => s.draftTaskId,
          );

          return Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacings.x2l,
              vertical: theme.spacings.lg,
            ),
            decoration: const BoxDecoration(color: Colors.transparent),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final projectField = _buildProjectSelector(
                  context,
                  isRunning,
                  draftProjectId,
                );
                final taskField = _buildTaskSelector(
                  context,
                  isRunning,
                  draftTaskId,
                );
                final commentField = _buildCommentInput(
                  context,
                  isRunning,
                  draftTaskId,
                );
                final timerAndAction = _buildTimerAndAction(
                  context,
                  isRunning,
                  theme,
                  palette,
                  projectTaskState,
                  draftProjectId,
                  draftTaskId,
                );

                if (constraints.maxWidth >= 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: projectField),
                            SizedBox(width: theme.spacings.lg),
                            Expanded(child: taskField),
                          ],
                        ),
                      ),
                      SizedBox(width: theme.spacings.xl),
                      Expanded(flex: 4, child: commentField),
                      SizedBox(width: theme.spacings.xl),
                      ...timerAndAction,
                    ],
                  );
                } else if (constraints.maxWidth >= 600) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: projectField),
                          SizedBox(width: theme.spacings.lg),
                          Expanded(child: taskField),
                        ],
                      ),
                      SizedBox(height: theme.spacings.lg),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: commentField),
                          SizedBox(width: theme.spacings.xl),
                          ...timerAndAction,
                        ],
                      ),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      projectField,
                      SizedBox(height: theme.spacings.lg),
                      taskField,
                      SizedBox(height: theme.spacings.lg),
                      commentField,
                      SizedBox(height: theme.spacings.xl),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: timerAndAction,
                      ),
                    ],
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildTimerAndAction(
    BuildContext context,
    bool isRunning,
    AppThemeExtension theme,
    ColorsPalette palette,
    ProjectTaskState projectTaskState,
    String? draftProjectId,
    String? draftTaskId,
  ) {
    return [
      ActiveTimerText(
        style: theme.commonTextStyles.h1.copyWith(
          color: isRunning ? palette.text.primary : palette.text.muted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      SizedBox(width: theme.spacings.xl),
      isRunning
          ? PrimaryButton(
              size: ButtonSize.sm,
              type: ButtonType.danger,
              title: 'STOP',
              leftIcon: WorklogStudioAssets.vectors.squareFilled64Svg,
              backgroundColor: palette.accent.danger,
              onTap: () {
                context.read<TimeTrackerBloc>().add(TimeTrackerStopped());
                projectTaskState.clearDraft();
                _commentController.clear();
              },
            )
          : PrimaryButton(
              size: ButtonSize.sm,
              title: 'START',
              leftIcon: WorklogStudioAssets.vectors.playFilled64Svg,
              onTap: () {
                context.read<TimeTrackerBloc>().add(
                  TimeTrackerStarted(
                    projectId: draftProjectId,
                    taskId: draftTaskId,
                    comment: _commentController.text.isNotEmpty
                        ? _commentController.text
                        : null,
                  ),
                );
              },
            ),
    ];
  }

  Widget _buildProjectSelector(
    BuildContext context,
    bool isRunning,
    String? selectedId,
  ) {
    final projectTaskState = context.read<ProjectTaskState>();
    final projects = context.select<ProjectTaskState, List<Project>>(
      (s) => s.projects,
    );

    final options = projects.map((p) {
      final initials = BadgeUtils.getProjectInitials(p.name);
      final colors = BadgeUtils.getBadgeColor(p.id);
      return SelectOption(
        value: p.id,
        label: p.name,
        leading: WsInitialBadge(
          initials: initials,
          backgroundColor: colors.$1,
          textColor: colors.$2,
          size: WsInitialBadgeSize.small,
        ),
      );
    }).toList();

    final selectedProject = projects
        .where((p) => p.id == selectedId)
        .firstOrNull;

    Widget? leadingWidget;
    if (selectedProject != null) {
      final initials = BadgeUtils.getProjectInitials(selectedProject.name);
      final colors = BadgeUtils.getBadgeColor(selectedProject.id);
      leadingWidget = WsInitialBadge(
        initials: initials,
        backgroundColor: colors.$1,
        textColor: colors.$2,
        size: WsInitialBadgeSize.small,
      );
    }

    return InlineField(
      label: 'PROJECT',
      value: selectedProject?.name ?? '',
      placeholder: 'Select Project',
      leading: leadingWidget,
      controller: _projectFieldController,
      editWidget: Select<String>(
        autoOpen: true,
        tapRegionGroupId: _projectFieldController.tapRegionGroupId,
        onOpenChange: (isOpen) {
          if (!isOpen) _projectFieldController.handleEditorClose();
        },
        value: selectedId,
        placeholder: 'Select Project',
        searchable: true,
        options: options,
        actionBuilder: (context, query, close) {
          final exactMatchExists = projects.any(
            (p) => p.name.toLowerCase() == query.toLowerCase(),
          );
          if (exactMatchExists && query.isNotEmpty) {
            return const SizedBox.shrink();
          }

          return SelectCreateAction(
            label: query.isEmpty
                ? 'Create new project'
                : 'Create project "$query"',
            onTap: () async {
              final newProject = await projectTaskState.createProject(
                query.isEmpty ? 'New project' : query,
                '',
              );
              projectTaskState.updateDraft(projectId: newProject.id);
              if (isRunning) {
                context.read<TimeTrackerBloc>().add(
                  TimeTrackerActiveEntryUpdated(
                    projectId: newProject.id,
                    taskId: projectTaskState.draftTaskId,
                    comment: _commentController.text,
                  ),
                );
              }
              close();
              _projectFieldController.exitEditMode();
            },
          );
        },
        onChanged: (value) async {
          projectTaskState.updateDraft(projectId: value);
          if (isRunning) {
            context.read<TimeTrackerBloc>().add(
              TimeTrackerActiveEntryUpdated(
                projectId: value,
                taskId: projectTaskState.draftTaskId,
                comment: _commentController.text,
              ),
            );
          }
          _projectFieldController.exitEditMode();
        },
      ),
    );
  }

  Widget _buildTaskSelector(
    BuildContext context,
    bool isRunning,
    String? selectedId,
  ) {
    final projectTaskState = context.read<ProjectTaskState>();
    final tasks = context.select<ProjectTaskState, List<Task>>((s) => s.tasks);
    final draftProjectId = context.select<ProjectTaskState, String?>(
      (s) => s.draftProjectId,
    );

    final filteredTasks = draftProjectId != null
        ? tasks.where((t) => t.projectId == draftProjectId).toList()
        : tasks;

    final options = filteredTasks.map((t) {
      final project = projectTaskState.projects.firstWhereOrNull(
        (p) => p.id == t.projectId,
      );
      final initials = BadgeUtils.getTaskInitials(t.title, project?.name ?? '');
      final colors = BadgeUtils.getBadgeColor(t.id);
      return SelectOption(
        value: t.id,
        label: t.title,
        leading: WsInitialBadge(
          initials: initials,
          backgroundColor: colors.$1,
          textColor: colors.$2,
          size: WsInitialBadgeSize.small,
        ),
      );
    }).toList();

    final selectedTask = filteredTasks
        .where((t) => t.id == selectedId)
        .firstOrNull;

    Widget? leadingWidget;
    if (selectedTask != null) {
      final project = projectTaskState.projects.firstWhere(
        (p) => p.id == selectedTask.projectId,
      );
      final initials = BadgeUtils.getTaskInitials(
        selectedTask.title,
        project.name,
      );
      final colors = BadgeUtils.getBadgeColor(selectedTask.id);
      leadingWidget = WsInitialBadge(
        initials: initials,
        backgroundColor: colors.$1,
        textColor: colors.$2,
        size: WsInitialBadgeSize.small,
      );
    }

    return InlineField(
      label: 'TASK',
      value: selectedTask?.title ?? '',
      placeholder: 'Select Task',
      leading: leadingWidget,
      controller: _taskFieldController,
      editWidget: Select<String>(
        autoOpen: true,
        tapRegionGroupId: _taskFieldController.tapRegionGroupId,
        onOpenChange: (isOpen) {
          if (!isOpen) _taskFieldController.handleEditorClose();
        },
        value: selectedId,
        placeholder: 'Select Task',
        searchable: true,
        options: options,
        actionBuilder: (context, query, close) {
          final exactMatchExists = tasks.any(
            (t) =>
                t.title.toLowerCase() == query.toLowerCase() &&
                t.projectId == draftProjectId,
          );
          if (exactMatchExists && query.isNotEmpty) {
            return const SizedBox.shrink();
          }

          return SelectCreateAction(
            label: query.isEmpty ? 'Create new task' : 'Create task "$query"',
            onTap: () async {
              if (draftProjectId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a project first'),
                  ),
                );
                return;
              }
              final newTask = await projectTaskState.createTask(
                draftProjectId,
                query.isEmpty ? 'New task' : query,
                '',
              );
              projectTaskState.updateDraft(taskId: newTask.id);
              if (isRunning) {
                context.read<TimeTrackerBloc>().add(
                  TimeTrackerActiveEntryUpdated(
                    projectId: draftProjectId,
                    taskId: newTask.id,
                    comment: _commentController.text,
                  ),
                );
              }
              close();
              _taskFieldController.exitEditMode();
            },
          );
        },
        onChanged: (value) async {
          if (value == null) {
            projectTaskState.updateDraft(clearTaskId: true);
          } else {
            projectTaskState.updateDraft(taskId: value);
          }
          if (isRunning) {
            context.read<TimeTrackerBloc>().add(
              TimeTrackerActiveEntryUpdated(
                projectId: draftProjectId,
                taskId: value,
                comment: _commentController.text,
              ),
            );
          }
          _taskFieldController.exitEditMode();
        },
      ),
    );
  }

  Widget _buildCommentInput(
    BuildContext context,
    bool isRunning,
    String? selectedId,
  ) {
    final projectTaskState = context.read<ProjectTaskState>();
    final draftProjectId = context.select<ProjectTaskState, String?>(
      (s) => s.draftProjectId,
    );

    return InlineField(
      label: 'COMMENT',
      value: _commentController.text,
      placeholder: 'Add a comment...',
      controller: _commentFieldController,
      textController: _commentController,
      editWidget: PrimaryInput(
        label: null,
        hintText: 'Add a comment...',
        controller: _commentController,
        autofocus: true,
        onChanged: (value) {
          if (isRunning) {
            context.read<TimeTrackerBloc>().add(
              TimeTrackerActiveEntryUpdated(
                projectId: draftProjectId,
                taskId: projectTaskState.draftTaskId,
                comment: value,
              ),
            );
          }
        },
      ),
    );
  }
}

class SidebarNavigation extends StatelessWidget {
  final AppRoute currentRoute;
  final ValueChanged<AppRoute> onRouteSelected;

  const SidebarNavigation({
    super.key,
    required this.currentRoute,
    required this.onRouteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: palette.background.surface,
        border: Border(right: BorderSide(color: palette.border.primary)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(theme.spacings.xl),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: palette.accent.primary,
                    borderRadius: theme.radiuses.sm.circular,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.work,
                      color: palette.background.surface,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(width: theme.spacings.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Worklog Studio',
                      style: theme.commonTextStyles.bodyBold,
                    ),
                    Text(
                      'PROFESSIONAL TRACKING',
                      style: theme.commonTextStyles.caption3Bold.copyWith(
                        color: palette.text.muted,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: theme.spacings.lg),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacings.md),
              child: Column(
                children: [
                  SidebarItem(
                    label: 'Dashboard',
                    isActive: currentRoute == AppRoute.dashboard,
                    onTap: () => onRouteSelected(AppRoute.dashboard),
                  ),
                  SidebarItem(
                    label: 'History',
                    isActive: currentRoute == AppRoute.history,
                    onTap: () => onRouteSelected(AppRoute.history),
                  ),
                  SidebarItem(
                    label: 'Projects',
                    isActive: currentRoute == AppRoute.projects,
                    onTap: () => onRouteSelected(AppRoute.projects),
                  ),
                  SidebarItem(
                    label: 'Tasks',
                    isActive: currentRoute == AppRoute.tasks,
                    onTap: () => onRouteSelected(AppRoute.tasks),
                  ),
                  SidebarItem(
                    label: 'Settings',
                    isActive: currentRoute == AppRoute.settings,
                    onTap: () => onRouteSelected(AppRoute.settings),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(theme.spacings.md),
            child: Column(
              children: [
                SidebarItem(label: 'Help', onTap: () {}),
                SidebarItem(label: 'Logout', onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
