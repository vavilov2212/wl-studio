import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide DrawerHeader;
import 'package:provider/provider.dart';
import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio/feature/common/presentation/components/drawer_content.dart';
import 'package:worklog_studio/feature/common/presentation/components/drawer_header.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field_controller.dart';
import 'package:worklog_studio/feature/common/presentation/resizable_drawer.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/feature/common/presentation/components/entity_meta_info_row.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/common/presentation/components/date_time_inline_field.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';
import 'package:worklog_studio/core/services/app_navigation_controller.dart';

class TimeEntryDrawer extends StatefulWidget {
  final ResolvedTimeEntry? resolvedEntry;
  final bool isOpen;
  final VoidCallback onClose;
  final DrawerMode mode;

  const TimeEntryDrawer({
    super.key,
    required this.resolvedEntry,
    required this.isOpen,
    required this.onClose,
    this.mode = DrawerMode.push,
  });

  @override
  State<TimeEntryDrawer> createState() => _TimeEntryDrawerState();
}

class _TimeEntryDrawerState extends State<TimeEntryDrawer> {
  bool _isConfirmingDelete = false;
  late ResolvedTimeEntry _draft;
  late TextEditingController _commentController;
  final InlineFieldController _projectFieldController = InlineFieldController();
  final InlineFieldController _taskFieldController = InlineFieldController();
  final InlineFieldController _commentFieldController = InlineFieldController();
  final InlineFieldController _startTimeFieldController =
      InlineFieldController();
  final InlineFieldController _endTimeFieldController = InlineFieldController();

  @override
  void initState() {
    super.initState();
    _initDraft();
    _initControllers();
  }

  void _initDraft() {
    if (widget.resolvedEntry != null) {
      _draft = widget.resolvedEntry!;
    } else {
      final now = DateTime.now();
      _draft = ResolvedTimeEntry(
        entry: TimeEntry(
          id: '',
          startAt: now,
          endAt: now.add(const Duration(hours: 1)),
          status: TimeEntryStatus.stopped,
        ),
        project: null,
        task: null,
      );
    }
  }

  void _initControllers() {
    _commentController = TextEditingController(
      text: _draft.entry.comment ?? '',
    );
    _commentFieldController.addListener(_onCommentEditModeChanged);
  }

  void _onCommentEditModeChanged() {
    if (!mounted) return;
    if (!_commentFieldController.isEditing) {
      if (_draft.entry.comment != _commentController.text) {
        _updateDraft(_draft.entry.copyWith(comment: _commentController.text));
      }
    }
  }

  void _updateDraft(TimeEntry updatedEntry) {
    if (updatedEntry.endAt != null &&
        updatedEntry.endAt!.isBefore(updatedEntry.startAt)) {
      // Auto-correct: Push endAt to match startAt if invalid
      updatedEntry = updatedEntry.copyWith(endAt: updatedEntry.startAt);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        final resolver = context.read<EntityResolver>();
        final resolvedProject = updatedEntry.projectId != null
            ? resolver.getResolvedProject(updatedEntry.projectId!)?.project
            : null;
        final resolvedTask = updatedEntry.taskId != null
            ? resolver.getResolvedTask(updatedEntry.taskId!)?.task
            : null;

        _draft = _draft.copyWith(
          entry: updatedEntry,
          project: resolvedProject,
          task: resolvedTask,
        );
      });
      if (!_isNew) {
        context.read<TimeTrackerBloc>().add(
          TimeTrackerEntryUpdated(updatedEntry),
        );
      }
    });
  }

  @override
  void didUpdateWidget(TimeEntryDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isOpen && oldWidget.isOpen) {
      _isConfirmingDelete = false;
    }
    if (widget.resolvedEntry != oldWidget.resolvedEntry ||
        widget.isOpen != oldWidget.isOpen) {
      _isConfirmingDelete = false;
      _initDraft();

      if (_commentController.text != (_draft.entry.comment ?? '')) {
        _commentController.text = _draft.entry.comment ?? '';
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _projectFieldController.dispose();
    _taskFieldController.dispose();
    _commentFieldController.removeListener(_onCommentEditModeChanged);
    _commentFieldController.dispose();
    _startTimeFieldController.dispose();
    _endTimeFieldController.dispose();
    super.dispose();
  }

  bool get _isNew => widget.resolvedEntry == null;

  void _handleSave() async {
    if (!_isNew) return; // Should not be called for existing entries

    final bloc = context.read<TimeTrackerBloc>();
    final newEntry = TimeEntry(
      id: '',
      projectId: _draft.projectId,
      taskId: _draft.taskId,
      comment: _commentController.text,
      startAt: _draft.startAt,
      endAt: _draft.endAt,
      status: TimeEntryStatus.stopped,
    );
    bloc.add(TimeTrackerEntryCreated(newEntry));
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final isActive = context.select<TimeTrackerBloc, bool>(
      (bloc) =>
          bloc.state.activeEntryOrNull?.id == _draft.entry.id &&
          _draft.entry.id.isNotEmpty,
    );

    return ResizableDrawer(
      isOpen: widget.isOpen,
      onClose: widget.onClose,
      mode: widget.mode,
      backgroundColor: palette.background.canvas,
      header: DrawerHeader(
        onClose: widget.onClose,
        onDelete: _isNew
            ? null
            : () {
                setState(() {
                  _isConfirmingDelete = true;
                });
              },
        onDiscard: _isNew ? widget.onClose : null,
      ),
      body: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return SizeTransition(
                          sizeFactor: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                  child: _isConfirmingDelete
                      ? Padding(
                          key: const ValueKey('delete_confirmation'),
                          padding: EdgeInsets.fromLTRB(
                            theme.spacings.xl,
                            theme.spacings.lg,
                            theme.spacings.xl,
                            0,
                          ),
                          child: InfoBar(
                            variant: InfoBarVariant.danger,
                            title: const Text('Delete this time entry?'), // TODO: l10n
                            description: const Text(
                              'This action cannot be undone', // TODO: l10n
                            ),
                            actions: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PrimaryButton(
                                  onTap: () {
                                    if (widget.resolvedEntry != null) {
                                      context.read<TimeTrackerBloc>().add(
                                        TimeTrackerEntryDeleted(
                                          widget.resolvedEntry!.entry.id,
                                        ),
                                      );
                                      widget.onClose();
                                    }
                                  },
                                  title: 'Delete', // TODO: l10n
                                  type: ButtonType.danger,
                                  size: ButtonSize.sm,
                                ),
                                SizedBox(width: theme.spacings.sm),
                                PrimaryButton(
                                  onTap: () {
                                    setState(() {
                                      _isConfirmingDelete = false;
                                    });
                                  },
                                  title: 'Cancel', // TODO: l10n
                                  type: ButtonType.ghost,
                                  size: ButtonSize.sm,
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('no_confirmation')),
                ),
                if (_isNew)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      theme.spacings.xl,
                      theme.spacings.md,
                      theme.spacings.xl,
                      theme.spacings.none,
                    ),
                    child: InfoBar(
                      variant: InfoBarVariant.info,
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Not saved yet'), // TODO: l10n
                      actions: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PrimaryButton(
                            onTap: widget.onClose,
                            title: 'Discard', // TODO: l10n
                            type: ButtonType.ghost,
                            size: ButtonSize.sm,
                          ),
                          SizedBox(width: theme.spacings.sm),
                          PrimaryButton(
                            onTap: _handleSave,
                            title: 'Save', // TODO: l10n
                            size: ButtonSize.sm,
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: DrawerContent(
                    meta: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_isNew) ...[
                          EntityMetaInfoRow(
                            status: isActive
                                ? BadgeStatus.inProgress
                                : BadgeStatus.ready,
                            statusLabel: isActive
                                ? 'RUNNING'
                                : getStatusText(_draft.entry.status),
                            createdAt: _draft.entry.startAt,
                            badgeSize: BadgeSize.sm,
                          ),
                        ],
                        LabeledDivider(label: 'Assignment'),
                        SizedBox(height: theme.spacings.lg),
                        BaseCard(
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Project Select
                                  Expanded(
                                    child: Consumer<ProjectTaskState>(
                                      builder: (context, state, child) {
                                        final selectedProject = state.projects
                                            .where(
                                              (p) => p.id == _draft.projectId,
                                            )
                                            .firstOrNull;

                                        Widget leadingProjectWidget;
                                        if (selectedProject != null) {
                                          final initials =
                                              BadgeUtils.getProjectInitials(
                                                selectedProject.name,
                                              );
                                          final colors =
                                              BadgeUtils.getBadgeColor(
                                                selectedProject.id,
                                              );
                                          leadingProjectWidget = WsInitialBadge(
                                            initials: initials,
                                            backgroundColor: colors.$1,
                                            textColor: colors.$2,
                                            size: WsInitialBadgeSize.small,
                                          );
                                        } else {
                                          leadingProjectWidget = Icon(
                                            Icons.folder_outlined,
                                            size: 18,
                                            color: palette.text.muted,
                                          );
                                        }

                                        return InlineField(
                                          label: 'Project',
                                          value: selectedProject?.name ?? '',
                                          placeholder: 'Select Project',
                                          leading: leadingProjectWidget,
                                          trailing: _selectChevron(palette),
                                          controller: _projectFieldController,
                                          editWidget: Select<String>(
                                            autoOpen: true,
                                            searchable: true,
                                            tapRegionGroupId:
                                                _projectFieldController
                                                    .tapRegionGroupId,
                                            onOpenChange: (isOpen) {
                                              if (!isOpen) {
                                                _projectFieldController
                                                    .handleEditorClose();
                                              }
                                            },
                                            value: _draft.projectId,
                                            placeholder: 'Select Project',
                                            onChanged: (value) {
                                              final updatedEntry = _draft.entry
                                                  .copyWith(
                                                    projectId: value,
                                                    taskId: null,
                                                  );

                                              _updateDraft(updatedEntry);

                                              _projectFieldController
                                                  .handleEditorCommit();
                                            },
                                            actionBuilder: (context, query, close) {
                                              final exactMatchExists = state
                                                  .projects
                                                  .any(
                                                    (p) =>
                                                        p.name.toLowerCase() ==
                                                        query.toLowerCase(),
                                                  );
                                              if (exactMatchExists &&
                                                  query.isNotEmpty)
                                                return const SizedBox.shrink();

                                              return SelectCreateAction(
                                                label: query.isEmpty
                                                    ? 'Create new project'
                                                    : 'Create project "$query"',
                                                onTap: () async {
                                                  final newProject = await state
                                                      .createProject(
                                                        query.isEmpty
                                                            ? 'New project'
                                                            : query,
                                                        '',
                                                      );
                                                  final updatedEntry = _draft
                                                      .entry
                                                      .copyWith(
                                                        projectId:
                                                            newProject.id,
                                                        taskId: null,
                                                      );
                                                  _updateDraft(updatedEntry);
                                                  _projectFieldController
                                                      .handleEditorCommit();
                                                  close();
                                                },
                                              );
                                            },
                                            options: state.projects.map((p) {
                                              final initials =
                                                  BadgeUtils.getProjectInitials(
                                                    p.name,
                                                  );
                                              final colors =
                                                  BadgeUtils.getBadgeColor(
                                                    p.id,
                                                  );
                                              return SelectOption(
                                                value: p.id,
                                                label: p.name,
                                                leading: WsInitialBadge(
                                                  initials: initials,
                                                  backgroundColor: colors.$1,
                                                  textColor: colors.$2,
                                                  size:
                                                      WsInitialBadgeSize.small,
                                                ),
                                                onAction: () => context
                                                    .read<
                                                      AppNavigationController
                                                    >()
                                                    .openProject(p.id),
                                                // TODO: l10n
                                                actionTooltip: 'Open project',
                                              );
                                            }).toList(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(width: theme.spacings.lg),
                                  // Task Select
                                  Expanded(
                                    child: Consumer<ProjectTaskState>(
                                      builder: (context, state, child) {
                                        final selectedTask = state.tasks
                                            .where((t) => t.id == _draft.taskId)
                                            .firstOrNull;

                                        Widget leadingTaskWidget;
                                        if (selectedTask != null) {
                                          final project = state.projects
                                              .firstWhereOrNull(
                                                (p) =>
                                                    p.id ==
                                                    selectedTask.projectId,
                                              );
                                          final initials =
                                              BadgeUtils.getTaskInitials(
                                                selectedTask.title,
                                                project?.name ?? '',
                                              );
                                          final colors =
                                              BadgeUtils.getBadgeColor(
                                                selectedTask.id,
                                              );
                                          leadingTaskWidget = WsInitialBadge(
                                            initials: initials,
                                            backgroundColor: colors.$1,
                                            textColor: colors.$2,
                                            size: WsInitialBadgeSize.small,
                                          );
                                        } else {
                                          leadingTaskWidget = Icon(
                                            Icons.checklist,
                                            size: 18,
                                            color: palette.text.muted,
                                          );
                                        }

                                        return InlineField(
                                          label: 'Task',
                                          value: selectedTask?.title ?? '',
                                          placeholder: 'Select Task',
                                          leading: leadingTaskWidget,
                                          trailing: _selectChevron(palette),
                                          controller: _taskFieldController,
                                          editWidget: Select<String>(
                                            autoOpen: true,
                                            searchable: true,
                                            tapRegionGroupId:
                                                _taskFieldController
                                                    .tapRegionGroupId,
                                            onOpenChange: (isOpen) {
                                              if (!isOpen) {
                                                _taskFieldController
                                                    .handleEditorClose();
                                              }
                                            },
                                            value: _draft.taskId,
                                            placeholder: 'Select Task',
                                            onChanged: (value) {
                                              final updatedEntry = _draft.entry
                                                  .copyWith(taskId: value);
                                              _updateDraft(updatedEntry);
                                              _taskFieldController
                                                  .handleEditorCommit();
                                            },
                                            actionBuilder: (context, query, close) {
                                              final exactMatchExists = state
                                                  .tasks
                                                  .any(
                                                    (t) =>
                                                        t.title.toLowerCase() ==
                                                            query
                                                                .toLowerCase() &&
                                                        t.projectId ==
                                                            _draft.projectId,
                                                  );
                                              if (exactMatchExists &&
                                                  query.isNotEmpty)
                                                return const SizedBox.shrink();

                                              return SelectCreateAction(
                                                label: query.isEmpty
                                                    ? 'Create new task'
                                                    : 'Create task "$query"',
                                                onTap: () async {
                                                  if (_draft.projectId == null)
                                                    return;
                                                  final newTask = await state
                                                      .createTask(
                                                        _draft.projectId!,
                                                        query.isEmpty
                                                            ? 'New task'
                                                            : query,
                                                        '',
                                                      );
                                                  final updatedEntry = _draft
                                                      .entry
                                                      .copyWith(
                                                        taskId: newTask.id,
                                                      );
                                                  _updateDraft(updatedEntry);
                                                  _taskFieldController
                                                      .handleEditorCommit();
                                                  close();
                                                },
                                              );
                                            },
                                            options: state.tasks
                                                .where(
                                                  (t) =>
                                                      t.projectId ==
                                                      _draft.projectId,
                                                )
                                                .map((t) {
                                                  final project = state.projects
                                                      .firstWhere(
                                                        (p) =>
                                                            p.id == t.projectId,
                                                      );
                                                  final initials =
                                                      BadgeUtils.getTaskInitials(
                                                        t.title,
                                                        project.name,
                                                      );
                                                  final colors =
                                                      BadgeUtils.getBadgeColor(
                                                        t.id,
                                                      );
                                                  return SelectOption(
                                                    value: t.id,
                                                    label: t.title,
                                                    leading: WsInitialBadge(
                                                      initials: initials,
                                                      backgroundColor:
                                                          colors.$1,
                                                      textColor: colors.$2,
                                                      size: WsInitialBadgeSize
                                                          .small,
                                                    ),
                                                    onAction: () => context
                                                        .read<
                                                          AppNavigationController
                                                        >()
                                                        .openTask(t.id),
                                                    // TODO: l10n
                                                    actionTooltip: 'Open task',
                                                  );
                                                })
                                                .toList(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: theme.spacings.lg),
                              // Comments
                              InlineField(
                                label: 'Comments',
                                value: _commentController.text,
                                placeholder: 'Add a comment...',
                                controller: _commentFieldController,
                                textController: _commentController,
                                isTextArea: true,
                                viewModeMaxLines: 3,
                                editWidget: TextArea(
                                  label: null,
                                  hintText: 'Add a comment...',
                                  controller: _commentController,
                                  autofocus: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    content: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spacings.x2l,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: theme.spacings.x2l),
                          LabeledDivider(label: 'Time & Cost'),
                          SizedBox(height: theme.spacings.lg),
                          BaseCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Timeline
                                Row(
                                  children: [
                                    Expanded(
                                      child: DateTimeInlineField(
                                        label: 'Start',
                                        value: _draft.startAt,
                                        controller: _startTimeFieldController,
                                        onChanged: (newStartAt) {
                                          _updateDraft(
                                            _draft.entry.copyWith(
                                              startAt: newStartAt,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    SizedBox(width: theme.spacings.lg),
                                    Expanded(
                                      child: DateTimeInlineField(
                                        label: 'End',
                                        value: _draft.endAt ?? DateTime.now(),
                                        isEditable: !isActive,
                                        controller: _endTimeFieldController,
                                        onChanged: (newEndAt) {
                                          _updateDraft(
                                            _draft.entry.copyWith(
                                              endAt: newEndAt,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: theme.spacings.x2l),
                                // Metrics Grid
                                Row(
                                  children: [
                                    Expanded(
                                      child: MetricCard(
                                        label: 'Duration',
                                        icon: Icons.timer_outlined,
                                        accent: isActive,
                                        value: isActive
                                            ? LiveDurationText(
                                                durationBuilder: (now) => now
                                                    .difference(_draft.startAt),
                                                style: theme
                                                    .commonTextStyles
                                                    .subtitle,
                                              )
                                            : Text(
                                                DateFormatter.formatDurationHms(
                                                  _draft.duration(
                                                    DateTime.now(),
                                                  ),
                                                ),
                                                style: theme
                                                    .commonTextStyles
                                                    .subtitle,
                                              ),
                                      ),
                                    ),
                                    SizedBox(width: theme.spacings.lg),
                                    Expanded(
                                      child: MetricCard(
                                        label: 'Cost est.',
                                        icon: Icons.payments_outlined,
                                        value: Text(
                                          r'$0.00',
                                          style:
                                              theme.commonTextStyles.subtitle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: theme.spacings.xl),
                        ],
                      ),
                    ),
                    footer: isActive
                        ? SizedBox(
                            width: double.infinity,
                            child: PrimaryButton(
                              onTap: () => context.read<TimeTrackerBloc>().add(
                                const TimeTrackerStopped(),
                              ),
                              title: 'Stop Timer',
                              leftIcon:
                                  WorklogStudioAssets.vectors.squareFilled24Svg,
                              type: ButtonType.danger,
                              size: ButtonSize.lg,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _selectChevron(ColorsPalette palette) {
    return Icon(Icons.keyboard_arrow_down, size: 18, color: palette.text.muted);
  }

  String getStatusText(TimeEntryStatus status) {
    switch (status) {
      case TimeEntryStatus.running:
        return 'RUNNING';
      case TimeEntryStatus.stopped:
        return 'STOPPED';
    }
  }

}
