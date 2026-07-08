import 'package:flutter/material.dart' hide DrawerHeader;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio/feature/common/bloc/drawer_form_cubit.dart';
import 'package:worklog_studio/feature/common/presentation/components/drawer_content.dart';
import 'package:worklog_studio/feature/common/presentation/components/drawer_header.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field_controller.dart';
import 'package:worklog_studio/feature/common/presentation/resizable_drawer.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/feature/common/presentation/components/delete_confirmation_row.dart';
import 'package:worklog_studio/feature/common/presentation/components/entity_meta_info_row.dart';
import 'package:worklog_studio/feature/common/presentation/components/project_selector.dart';
import 'package:worklog_studio/feature/common/presentation/components/task_selector.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/common/presentation/components/date_time_inline_field.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';

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
  late DrawerFormCubit<ResolvedTimeEntry> _formCubit;
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
    _formCubit = DrawerFormCubit<ResolvedTimeEntry>(_buildInitialDraft());
    _initControllers();
  }

  ResolvedTimeEntry _buildInitialDraft() {
    if (widget.resolvedEntry != null) {
      return widget.resolvedEntry!;
    } else {
      final now = DateTime.now();
      return ResolvedTimeEntry(
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
      text: _formCubit.state.draft.entry.comment ?? '',
    );
    _commentFieldController.addListener(_onCommentEditModeChanged);
  }

  void _onCommentEditModeChanged() {
    if (!mounted) return;
    if (!_commentFieldController.isEditing) {
      if (_formCubit.state.draft.entry.comment != _commentController.text) {
        _updateDraft(
          _formCubit.state.draft.entry.copyWith(
            comment: _commentController.text,
          ),
        );
      }
    }
  }

  void _updateDraft(TimeEntry updatedEntry) {
    if (updatedEntry.endAt != null &&
        updatedEntry.endAt!.isBefore(updatedEntry.startAt)) {
      updatedEntry = updatedEntry.copyWith(endAt: updatedEntry.startAt);
    }
    if (!mounted) return;
    final resolver = context.read<EntityResolver>();
    final resolvedProject = updatedEntry.projectId != null
        ? resolver.getResolvedProject(updatedEntry.projectId!)?.project
        : null;
    final resolvedTask = updatedEntry.taskId != null
        ? resolver.getResolvedTask(updatedEntry.taskId!)?.task
        : null;
    _formCubit.updateDraft(
      _formCubit.state.draft.copyWith(
        entry: updatedEntry,
        project: resolvedProject,
        task: resolvedTask,
      ),
    );
    if (!_isNew) {
      context.read<TimeTrackerBloc>().add(
        TimeTrackerEntryUpdated(updatedEntry),
      );
    }
  }

  @override
  void didUpdateWidget(TimeEntryDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isOpen && oldWidget.isOpen) {
      _formCubit.cancelDelete();
    }
    if (widget.resolvedEntry != oldWidget.resolvedEntry ||
        widget.isOpen != oldWidget.isOpen) {
      _formCubit.cancelDelete();
      final newDraft = _buildInitialDraft();
      _formCubit.reset(newDraft);
      final newComment = newDraft.entry.comment ?? '';
      if (_commentController.text != newComment) {
        _commentController.text = newComment;
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
    _formCubit.close();
    super.dispose();
  }

  bool get _isNew => widget.resolvedEntry == null;

  void _handleSave() async {
    if (!_isNew) return;
    final draft = _formCubit.state.draft;
    final bloc = context.read<TimeTrackerBloc>();
    final newEntry = TimeEntry(
      id: '',
      projectId: draft.projectId,
      taskId: draft.taskId,
      comment: _commentController.text,
      startAt: draft.startAt,
      endAt: draft.endAt,
      status: TimeEntryStatus.stopped,
    );
    bloc.add(TimeTrackerEntryCreated(newEntry));
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<
      DrawerFormCubit<ResolvedTimeEntry>,
      DrawerFormState<ResolvedTimeEntry>
    >(
      bloc: _formCubit,
      builder: (context, formState) {
        final theme = context.theme;
        final palette = theme.colorsPalette;
        final draft = formState.draft;
        final isConfirmingDelete = formState.confirmingDelete;

        final isActive = context.select<TimeTrackerBloc, bool>(
          (bloc) =>
              bloc.state.activeEntryOrNull?.id == draft.entry.id &&
              draft.entry.id.isNotEmpty,
        );

        return ResizableDrawer(
          isOpen: widget.isOpen,
          onClose: widget.onClose,
          mode: widget.mode,
          backgroundColor: palette.background.canvas,
          header: DrawerHeader(
            onClose: widget.onClose,
            onDelete: _isNew ? null : _formCubit.requestDelete,
            onDiscard: _isNew ? widget.onClose : null,
          ),
          body: Column(
            children: [
              DeleteConfirmationRow(
                isShowing: isConfirmingDelete,
                entityLabel: 'time entry',
                onConfirm: () {
                  if (widget.resolvedEntry != null) {
                    context.read<TimeTrackerBloc>().add(
                      TimeTrackerEntryDeleted(widget.resolvedEntry!.entry.id),
                    );
                    widget.onClose();
                  }
                },
                onCancel: _formCubit.cancelDelete,
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
                              : getStatusText(draft.entry.status),
                          createdAt: draft.entry.startAt,
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
                                  child: ProjectSelector(
                                    selectedProjectId: draft.projectId,
                                    fieldController: _projectFieldController,
                                    fallbackLeading: Icon(
                                      Icons.folder_outlined,
                                      size: 18,
                                      color: palette.text.muted,
                                    ),
                                    trailing: _selectChevron(palette),
                                    onProjectSelected: (value) {
                                      _updateDraft(
                                        draft.entry.copyWith(
                                          projectId: value,
                                          taskId: null,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(width: theme.spacings.lg),
                                // Task Select
                                Expanded(
                                  child: TaskSelector(
                                    projectId: draft.projectId,
                                    selectedTaskId: draft.taskId,
                                    fieldController: _taskFieldController,
                                    fallbackLeading: Icon(
                                      Icons.checklist,
                                      size: 18,
                                      color: palette.text.muted,
                                    ),
                                    trailing: _selectChevron(palette),
                                    onTaskSelected: (value) {
                                      _updateDraft(
                                        draft.entry.copyWith(taskId: value),
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
                                      value: draft.startAt,
                                      controller: _startTimeFieldController,
                                      onChanged: (newStartAt) {
                                        _updateDraft(
                                          draft.entry.copyWith(
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
                                      value: draft.endAt ?? DateTime.now(),
                                      isEditable: !isActive,
                                      controller: _endTimeFieldController,
                                      onChanged: (newEndAt) {
                                        _updateDraft(
                                          draft.entry.copyWith(endAt: newEndAt),
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
                                              durationBuilder: (now) =>
                                                  now.difference(draft.startAt),
                                              style: theme
                                                  .commonTextStyles
                                                  .subtitle,
                                            )
                                          : Text(
                                              DateFormatter.formatDurationHms(
                                                draft.duration(DateTime.now()),
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
                                        style: theme.commonTextStyles.subtitle,
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
      },
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
