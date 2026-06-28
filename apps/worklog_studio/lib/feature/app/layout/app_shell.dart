import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/feature/settings/general_settings_screen.dart';
import 'package:worklog_studio/feature/settings/hotkey_settings_screen.dart';
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
import 'package:worklog_studio/core/services/app_navigation_controller.dart';
import 'package:worklog_studio/feature/app/layout/app_drawer_host.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'dart:async';

enum AppRoute { dashboard, history, projects, tasks, settingsGeneral, settingsHotkeys }

/// Whether [route] belongs to the Settings section of the sidebar.
bool isSettingsRoute(AppRoute route) =>
    route == AppRoute.settingsGeneral || route == AppRoute.settingsHotkeys;

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
    context.read<AppNavigationController>().registerHandlers(
      openTask: _openTask,
      openProject: _openProject,
      openHistoryEntry: _openHistoryEntry,
    );
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

  /// Plain tab switch — no entity carried over, so the shared drawer closes.
  void _onRouteSelected(AppRoute route) {
    context.read<DrawerHostController>().close();
    setState(() {
      _currentRoute = route;
    });
  }

  /// Deep-link navigation — resolves the entity and opens the shared drawer
  /// *before* switching tabs, so the freshly-mounted page already sees it.
  void _openHistoryEntry(String entryId) {
    final resolved = context
        .read<EntityResolver>()
        .getResolvedTimeEntries()
        .firstWhereOrNull((e) => e.entry.id == entryId);
    if (resolved != null) {
      context.read<DrawerHostController>().openTimeEntryEdit(resolved.entry);
    }
    setState(() {
      _currentRoute = AppRoute.history;
    });
  }

  void _openHistoryCreateEntry() {
    context.read<DrawerHostController>().openTimeEntryCreate();
    setState(() {
      _currentRoute = AppRoute.history;
    });
  }

  void _openTask(String taskId) {
    final resolved = context
        .read<EntityResolver>()
        .getResolvedTasks()
        .firstWhereOrNull((t) => t.id == taskId);
    if (resolved != null) {
      context.read<DrawerHostController>().openTaskEdit(resolved.task);
    }
    setState(() {
      _currentRoute = AppRoute.tasks;
    });
  }

  void _openProject(String projectId) {
    final resolved = context
        .read<EntityResolver>()
        .getResolvedProjects()
        .firstWhereOrNull((p) => p.id == projectId);
    if (resolved != null) {
      context.read<DrawerHostController>().openProjectEdit(resolved.project);
    }
    setState(() {
      _currentRoute = AppRoute.projects;
    });
  }

  /// Builds only the active page. Replacing the previous IndexedStack means
  /// the previous page's widget leaves the tree and Flutter disposes it —
  /// this is the fix for pages staying resident in memory forever.
  Widget _buildActiveScreen() {
    switch (_currentRoute) {
      case AppRoute.dashboard:
        return HomePage(
          title: 'Dashboard',
          onViewAllHistory: () => _onRouteSelected(AppRoute.history),
          onSelectHistoryEntry: _openHistoryEntry,
          onAddTimeEntry: _openHistoryCreateEntry,
        );
      case AppRoute.history:
        return const HistoryScreen();
      case AppRoute.projects:
        return const ProjectsScreen();
      case AppRoute.tasks:
        return const TasksScreen();
      case AppRoute.settingsGeneral:
        return const GeneralSettingsScreen();
      case AppRoute.settingsHotkeys:
        return const HotkeySettingsScreen();
    }
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
                TopAppBar(
                  onOpenProject: _openProject,
                  onOpenTask: _openTask,
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildActiveScreen()),
                      const AppDrawerHost(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TopAppBar extends StatelessWidget {
  final ValueChanged<String> onOpenProject;
  final ValueChanged<String> onOpenTask;

  const TopAppBar({
    super.key,
    required this.onOpenProject,
    required this.onOpenTask,
  });

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
      child: GlobalTimeTrackerPanel(
        onOpenProject: onOpenProject,
        onOpenTask: onOpenTask,
      ),
    );
  }
}

class GlobalTimeTrackerPanel extends StatefulWidget {
  final ValueChanged<String> onOpenProject;
  final ValueChanged<String> onOpenTask;

  const GlobalTimeTrackerPanel({
    super.key,
    required this.onOpenProject,
    required this.onOpenTask,
  });

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
              vertical: theme.spacings.sm,
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
              type: ButtonType.danger,
              size: ButtonSize.sm,
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
        onAction: () => widget.onOpenProject(p.id),
        // TODO: l10n
        actionTooltip: 'Open project',
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
      label: 'Project',
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
        onAction: () => widget.onOpenTask(t.id),
        // TODO: l10n
        actionTooltip: 'Open task',
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
      label: 'Task',
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
      label: 'Comment',
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

class SidebarNavigation extends StatefulWidget {
  final AppRoute currentRoute;
  final ValueChanged<AppRoute> onRouteSelected;

  const SidebarNavigation({
    super.key,
    required this.currentRoute,
    required this.onRouteSelected,
  });

  @override
  State<SidebarNavigation> createState() => _SidebarNavigationState();
}

class _SidebarNavigationState extends State<SidebarNavigation> {
  bool _collapsed = true;
  bool _headerHovered = false;
  bool _settingsExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final navBg = palette.accent.nav;
    final collapsedWidth = 56.0;
    final expandedWidth = 220.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _collapsed ? collapsedWidth : expandedWidth,
      decoration: BoxDecoration(
        color: navBg,
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          // Brand + toggle — the whole row is clickable to expand/collapse.
          Tooltip(
            message: _collapsed ? 'Expand sidebar' : 'Collapse sidebar',
            preferBelow: true,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _headerHovered = true),
              onExit: (_) => setState(() => _headerHovered = false),
              child: GestureDetector(
                onTap: () => setState(() => _collapsed = !_collapsed),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 56,
                  color: _headerHovered
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.transparent,
                  padding: EdgeInsets.symmetric(horizontal: theme.spacings.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        margin: EdgeInsets.only(
                          left: _collapsed ? 4 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: theme.radiuses.sm.circular,
                        ),
                        child: Icon(
                          Icons.access_time_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      if (!_collapsed) ...[
                        SizedBox(width: theme.spacings.sm),
                        Expanded(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _collapsed ? 0 : 1,
                            child: Text(
                              'Worklog Studio',
                              style: theme.commonTextStyles.labelMedium
                                  .copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Nav items
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _collapsed ? 8 : theme.spacings.sm,
                vertical: theme.spacings.sm,
              ),
              child: Column(
                spacing: theme.spacings.xxs,
                children: [
                  _navItem(AppRoute.dashboard, 'Dashboard', Icons.grid_view_rounded),
                  _navItem(AppRoute.history, 'History', Icons.history_rounded),
                  if (!_collapsed)
                    Padding(
                      padding: EdgeInsets.only(
                        top: theme.spacings.md,
                        bottom: theme.spacings.xxs,
                        left: theme.spacings.lg,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Manage',
                          style: theme.commonTextStyles.labelSmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.25),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(height: theme.spacings.sm),
                  _navItem(AppRoute.projects, 'Projects', Icons.folder_outlined),
                  _navItem(AppRoute.tasks, 'Tasks', Icons.check_box_outlined),
                  if (!_collapsed)
                    Padding(
                      padding: EdgeInsets.only(
                        top: theme.spacings.md,
                        bottom: theme.spacings.xxs,
                        left: theme.spacings.lg,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'General',
                          style: theme.commonTextStyles.labelSmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.25),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(height: theme.spacings.sm),
                  ..._settingsNavGroup(),
                ],
              ),
            ),
          ),
          // Footer
          Container(
            height: 56,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: _collapsed ? 8 : 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  margin: EdgeInsets.only(left: _collapsed ? 4 : 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'WS',
                    style: theme.commonTextStyles.caption3Bold.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 9,
                    ),
                  ),
                ),
                if (!_collapsed) ...[
                  SizedBox(width: theme.spacings.sm),
                  Expanded(
                    child: Text(
                      'Worklog Studio',
                      style: theme.commonTextStyles.labelSmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(AppRoute route, String label, IconData icon) {
    final theme = context.theme;
    return SidebarItem(
      label: label,
      icon: icon,
      isActive: widget.currentRoute == route,
      collapsed: _collapsed,
      onTap: () => widget.onRouteSelected(route),
    );
  }

  /// The expandable "Settings" entry plus its "General"/"Hotkeys" children.
  ///
  /// When the sidebar itself is collapsed (icon-only mode) there's no room
  /// to show children inline, so tapping the parent navigates straight to
  /// the active settings sub-route (or General by default) instead of
  /// toggling an expansion that wouldn't be visible anyway.
  List<Widget> _settingsNavGroup() {
    final isOnSettings = isSettingsRoute(widget.currentRoute);

    final parent = SidebarItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      isActive: isOnSettings && (_collapsed || !_settingsExpanded),
      collapsed: _collapsed,
      trailing: _collapsed
          ? null
          : Icon(
              _settingsExpanded
                  ? Icons.expand_more_rounded
                  : Icons.chevron_right_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.45),
            ),
      onTap: () {
        if (_collapsed) {
          // No room to show General/Hotkeys inline while collapsed - expand
          // the whole sidebar so they become reachable, rather than
          // guessing which one the user wants.
          setState(() {
            _collapsed = false;
            _settingsExpanded = true;
          });
        } else {
          setState(() => _settingsExpanded = !_settingsExpanded);
        }
      },
    );

    if (_collapsed || !_settingsExpanded) {
      return [parent];
    }

    return [
      parent,
      _subNavItem(AppRoute.settingsGeneral, 'General'),
      _subNavItem(AppRoute.settingsHotkeys, 'Hotkeys'),
    ];
  }

  /// A nested item under the expandable "Settings" entry. Reuses
  /// [SidebarItem] itself (rather than a bespoke widget) so sub-items get
  /// the exact same hover/active/full-width row behavior as top-level
  /// items - `dense: true` gives them the lighter visual weight expected
  /// of a subordinate entry, and `indent` nests them under their parent.
  Widget _subNavItem(AppRoute route, String label) {
    final theme = context.theme;
    return SidebarItem(
      label: label,
      isActive: widget.currentRoute == route,
      indent: theme.spacings.xl,
      variant: SidebarItemVariant.nested,
      onTap: () => widget.onRouteSelected(route),
    );
  }
}
