import 'package:flutter/material.dart' hide DrawerHeader;
import 'package:intl/intl.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/feature/common/presentation/components/drawer_content.dart';
import 'package:worklog_studio/feature/common/presentation/components/drawer_header.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field_controller.dart';
import 'package:worklog_studio/feature/common/presentation/resizable_drawer.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/feature/common/presentation/components/entity_meta_info_row.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio/core/services/app_navigation_controller.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/state/entity_resolver.dart';

class TaskDrawer extends StatefulWidget {
  final Task? task;
  final bool isOpen;
  final VoidCallback onClose;

  const TaskDrawer({
    super.key,
    required this.task,
    required this.isOpen,
    required this.onClose,
  });

  @override
  State<TaskDrawer> createState() => _TaskDrawerState();
}

class _TaskDrawerState extends State<TaskDrawer> {
  bool _isConfirmingDelete = false;
  late Task _draft;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  final InlineFieldController _titleFieldController = InlineFieldController();
  final InlineFieldController _descriptionFieldController =
      InlineFieldController();
  final InlineFieldController _projectFieldController = InlineFieldController();

  @override
  void initState() {
    super.initState();
    _initDraft();
    _initControllers();
    _titleFieldController.addListener(_onTitleEditModeChanged);
    _descriptionFieldController.addListener(_onDescriptionEditModeChanged);
  }

  void _initDraft() {
    if (widget.task != null) {
      _draft = widget.task!;
    } else {
      _draft = Task(
        id: '',
        projectId: '',
        title: '',
        description: '',
        status: TaskStatus.open,
        createdAt: DateTime.now(),
      );
    }
  }

  void _initControllers() {
    _titleController = TextEditingController(text: _draft.title);
    _descriptionController = TextEditingController(text: _draft.description);
  }

  void _onTitleEditModeChanged() {
    if (!mounted) return;
    if (!_titleFieldController.isEditing && _draft.title != _titleController.text) {
      _updateDraft(_draft.copyWith(title: _titleController.text));
    }
  }

  void _onDescriptionEditModeChanged() {
    if (!mounted) return;
    if (!_descriptionFieldController.isEditing &&
        _draft.description != _descriptionController.text) {
      _updateDraft(_draft.copyWith(description: _descriptionController.text));
    }
  }

  void _updateDraft(Task updatedTask) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _draft = updatedTask);
      if (!_isNew) {
        context.read<ProjectTaskState>().updateTask(updatedTask);
      }
    });
  }

  @override
  void didUpdateWidget(TaskDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isOpen && oldWidget.isOpen) {
      _isConfirmingDelete = false;
    }
    if (widget.task != oldWidget.task || widget.isOpen != oldWidget.isOpen) {
      _isConfirmingDelete = false;
      _initDraft();
      _initControllers();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFieldController.removeListener(_onTitleEditModeChanged);
    _titleFieldController.dispose();
    _descriptionFieldController.removeListener(_onDescriptionEditModeChanged);
    _descriptionFieldController.dispose();
    _projectFieldController.dispose();
    super.dispose();
  }

  bool get _isNew => widget.task == null;

  void _handleSave() async {
    if (!_isNew) return;
    if (_draft.projectId.isNotEmpty && _titleController.text.isNotEmpty) {
      await context.read<ProjectTaskState>().createTask(
        _draft.projectId,
        _titleController.text,
        _descriptionController.text,
      );
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return ResizableDrawer(
      isOpen: widget.isOpen,
      onClose: widget.onClose,
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
      body: _draft == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                if (!_isNew)
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
                              title: const Text('Delete this task?'),
                              description: const Text(
                                'This action cannot be undone',
                              ),
                              actions: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PrimaryButton(
                                    onTap: () {
                                      if (widget.task != null) {
                                        context
                                            .read<ProjectTaskState>()
                                            .deleteTask(widget.task!.id);
                                        widget.onClose();
                                      }
                                    },
                                    title: 'Delete',
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
                                    title: 'Cancel',
                                    type: ButtonType.ghost,
                                    size: ButtonSize.sm,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('no_confirmation'),
                          ),
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
                          // Status Badge
                          EntityMetaInfoRow(
                            status: widget.task!.status == TaskStatus.done
                                ? BadgeStatus.done
                                : widget.task!.status == TaskStatus.archived
                                ? BadgeStatus.ready
                                : BadgeStatus.inProgress,
                            statusLabel: _getStatusText(widget.task!.status),
                            createdAt: widget.task!.createdAt,
                          ),
                        ],

                        LabeledDivider(label: 'Assignment'),
                        SizedBox(height: theme.spacings.lg),
                        BaseCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title Input
                              InlineField(
                                label: 'Task title',
                                value: _titleController.text,
                                placeholder: 'Enter task title...',
                                controller: _titleFieldController,
                                textController: _titleController,
                                editWidget: PrimaryInput(
                                  label: null,
                                  hintText: 'Enter task title...',
                                  controller: _titleController,
                                  autofocus: true,
                                ),
                              ),
                              SizedBox(height: theme.spacings.lg),
                              // Notes
                              InlineField(
                                label: 'Notes',
                                value: _descriptionController.text,
                                placeholder: 'Add a description...',
                                controller: _descriptionFieldController,
                                textController: _descriptionController,
                                isTextArea: true,
                                viewModeMaxLines: 3,
                                editWidget: TextArea(
                                  label: null,
                                  hintText: 'Add a description...',
                                  controller: _descriptionController,
                                  autofocus: true,
                                ),
                              ),
                              SizedBox(height: theme.spacings.lg),
                              // Details Grid
                              Row(
                                children: [
                                  Expanded(
                                    child: Consumer<ProjectTaskState>(
                                      builder: (context, state, child) {
                                        final selectedProject = state.projects
                                            .where(
                                              (p) => p.id == _draft.projectId,
                                            )
                                            .firstOrNull;

                                        Widget? leadingProjectWidget;
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
                                        }

                                        return InlineField(
                                          label: 'Project',
                                          value: selectedProject?.name ?? '',
                                          placeholder: 'Select Project',
                                          leading: leadingProjectWidget,
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
                                              _updateDraft(
                                                _draft.copyWith(projectId: value),
                                              );
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
                                                  query.isNotEmpty) {
                                                return const SizedBox.shrink();
                                              }

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
                                                  setState(() {
                                                    _draft = _draft.copyWith(
                                                      projectId: newProject.id,
                                                    );
                                                  });
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
                                  Expanded(
                                    child: _DetailItem(
                                      label: 'PRIORITY',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            size: 16,
                                            color: palette.text.secondary,
                                          ),
                                          SizedBox(width: theme.spacings.sm),
                                          Text(
                                            'Medium',
                                            style: theme.commonTextStyles.body
                                                .copyWith(
                                                  color: palette.text.primary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!_isNew) ...[
                                SizedBox(height: theme.spacings.xl),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DetailItem(
                                        label: 'ASSIGNEE',
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 12,
                                              backgroundColor:
                                                  palette.border.primary,
                                              child: Icon(
                                                Icons.person,
                                                size: 16,
                                                color: palette.text.secondary,
                                              ),
                                            ),
                                            SizedBox(width: theme.spacings.sm),
                                            Text(
                                              'Unassigned',
                                              style: theme
                                                  .commonTextStyles
                                                  .bodyBold,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _DetailItem(
                                        label: 'DUE DATE',
                                        child: Text(
                                          _formatDate(widget.task!.createdAt),
                                          style: theme.commonTextStyles.body,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    content: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spacings.x2l,
                        vertical: 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_isNew) ...[
                            SizedBox(height: theme.spacings.x2l),
                            LabeledDivider(label: 'Time Entries'),
                            SizedBox(height: theme.spacings.lg),
                            Builder(
                              builder: (context) {
                                final timeEntries =
                                    context
                                        .watch<EntityResolver>()
                                        .getResolvedTask(widget.task!.id)
                                        ?.timeEntries ??
                                    const <TimeEntry>[];

                                if (timeEntries.isEmpty) {
                                  return Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: theme.spacings.xl,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'No time entries logged for this task yet.',
                                        style: theme.commonTextStyles.body
                                            .copyWith(
                                              color: palette.text.muted,
                                            ),
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  spacing: theme.spacings.lg,
                                  children: timeEntries.map((entry) {
                                    return MasterListCard(
                                      title:
                                          (entry.comment?.isNotEmpty ?? false)
                                          ? entry.comment!
                                          : 'No comment',
                                      metadata: _formatEntryRange(entry),
                                      trailing: Text(
                                        DateFormatter.formatDurationHms(
                                          entry.duration(DateTime.now()),
                                        ),
                                        style: theme.commonTextStyles.bodyBold,
                                      ),
                                      onTap: () => context
                                          .read<AppNavigationController>()
                                          .openHistoryEntry(entry.id),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                            SizedBox(height: theme.spacings.x2l),
                            LabeledDivider(label: 'Activity'),
                            SizedBox(height: theme.spacings.lg),
                            Text(
                              'No activity yet.',
                              style: theme.commonTextStyles.body.copyWith(
                                color: palette.text.muted,
                              ),
                            ),
                          ],
                          SizedBox(height: theme.spacings.xl),
                        ],
                      ),
                    ),
                    footer: null,
                  ),
                ),
              ],
            ),
    );
  }

  String _formatEntryRange(TimeEntry entry) {
    final start = entry.startAt;
    final datePart = '${DateFormat.MMM().format(start)} ${start.day}';
    final startTime = DateFormatter.formatTimeHhMm(start);
    if (entry.endAt == null) {
      return '$datePart, $startTime - now';
    }
    final endTime = DateFormatter.formatTimeHhMm(entry.endAt!);
    return '$datePart, $startTime - $endTime';
  }

  String _getStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return 'OPEN';
      case TaskStatus.done:
        return 'DONE';
      case TaskStatus.archived:
        return 'ARCHIVED';
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final Widget child;

  const _DetailItem({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.commonTextStyles.caption3Bold.copyWith(
            color: palette.text.muted,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(height: theme.spacings.sm),
        child,
      ],
    );
  }
}
