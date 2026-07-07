import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field_controller.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/tracker_panel_cubit.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/active_timer_text.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return BlocListener<TrackerPanelCubit, TrackerPanelState>(
      listenWhen: (previous, current) =>
          previous.draftComment != current.draftComment,
      listener: (context, state) {
        if (_commentController.text != state.draftComment) {
          _commentController.text = state.draftComment;
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
                );
                final timerAndAction = _buildTimerAndAction(
                  context,
                  isRunning,
                  theme,
                  palette,
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
    String? draftProjectId,
    String? draftTaskId,
  ) {
    final cubit = context.read<TrackerPanelCubit>();
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
              onTap: cubit.stopTimer,
            )
          : PrimaryButton(
              size: ButtonSize.sm,
              leftIcon: WorklogStudioAssets.vectors.playFilled64Svg,
              onTap: cubit.startTimer,
            ),
    ];
  }

  Widget _buildProjectSelector(
    BuildContext context,
    bool isRunning,
    String? selectedId,
  ) {
    final cubit = context.read<TrackerPanelCubit>();
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

    final selectedProject =
        projects.where((p) => p.id == selectedId).firstOrNull;

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
              await cubit.createProject(
                query.isEmpty ? 'New project' : query,
                isRunning: isRunning,
              );
              close();
              _projectFieldController.exitEditMode();
            },
          );
        },
        onChanged: (value) {
          cubit.updateProject(value, isRunning: isRunning);
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
    final cubit = context.read<TrackerPanelCubit>();
    final tasks = context.select<ProjectTaskState, List<Task>>((s) => s.tasks);
    final draftProjectId = context.select<ProjectTaskState, String?>(
      (s) => s.draftProjectId,
    );
    final projectTaskState = context.read<ProjectTaskState>();

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

    final selectedTask =
        filteredTasks.where((t) => t.id == selectedId).firstOrNull;

    Widget? leadingWidget;
    if (selectedTask != null) {
      final project = projectTaskState.projects.firstWhereOrNull(
        (p) => p.id == selectedTask.projectId,
      );
      final initials = BadgeUtils.getTaskInitials(
        selectedTask.title,
        project?.name ?? '',
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
              await cubit.createTask(
                query.isEmpty ? 'New task' : query,
                isRunning: isRunning,
              );
              close();
              _taskFieldController.exitEditMode();
            },
          );
        },
        onChanged: (value) {
          cubit.updateTask(value, isRunning: isRunning);
          _taskFieldController.exitEditMode();
        },
      ),
    );
  }

  Widget _buildCommentInput(BuildContext context, bool isRunning) {
    final cubit = context.read<TrackerPanelCubit>();
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
        onChanged: (value) =>
            cubit.updateComment(value, isRunning: isRunning),
      ),
    );
  }
}
