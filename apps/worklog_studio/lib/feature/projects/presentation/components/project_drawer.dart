import 'package:flutter/material.dart' hide DrawerHeader;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/feature/common/bloc/drawer_form_cubit.dart';
import 'package:worklog_studio/feature/common/presentation/components/delete_confirmation_row.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field_controller.dart';
import 'package:worklog_studio/feature/common/presentation/resizable_drawer.dart';
import 'package:worklog_studio/feature/common/presentation/components/drawer_content.dart';
import 'package:worklog_studio/feature/common/presentation/components/drawer_header.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/feature/common/presentation/components/entity_meta_info_row.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/core/services/app_navigation_controller.dart';

class ProjectDrawer extends StatefulWidget {
  final Project? project;
  final bool isOpen;
  final VoidCallback onClose;
  final DrawerMode mode;

  const ProjectDrawer({
    super.key,
    required this.project,
    required this.isOpen,
    required this.onClose,
    this.mode = DrawerMode.push,
  });

  @override
  State<ProjectDrawer> createState() => _ProjectDrawerState();
}

class _ProjectDrawerState extends State<ProjectDrawer> {
  late DrawerFormCubit<Project> _formCubit;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final InlineFieldController _nameFieldController = InlineFieldController();
  final InlineFieldController _descriptionFieldController =
      InlineFieldController();

  @override
  void initState() {
    super.initState();
    _formCubit = DrawerFormCubit<Project>(_buildInitialDraft());
    _initControllers();
    _nameFieldController.addListener(_onNameEditModeChanged);
    _descriptionFieldController.addListener(_onDescriptionEditModeChanged);
  }

  Project _buildInitialDraft() {
    return widget.project ??
        Project(
          id: '',
          name: '',
          description: '',
          createdAt: DateTime.now(),
          status: ProjectStatus.open,
        );
  }

  void _initControllers() {
    _nameController =
        TextEditingController(text: _formCubit.state.draft.name);
    _descriptionController =
        TextEditingController(text: _formCubit.state.draft.description);
  }

  void _onNameEditModeChanged() {
    if (!mounted) return;
    if (!_nameFieldController.isEditing &&
        _formCubit.state.draft.name != _nameController.text) {
      _updateDraft(_formCubit.state.draft.copyWith(name: _nameController.text));
    }
  }

  void _onDescriptionEditModeChanged() {
    if (!mounted) return;
    if (!_descriptionFieldController.isEditing &&
        _formCubit.state.draft.description != _descriptionController.text) {
      _updateDraft(
        _formCubit.state.draft.copyWith(
          description: _descriptionController.text,
        ),
      );
    }
  }

  void _updateDraft(Project updatedProject) {
    if (!mounted) return;
    _formCubit.updateDraft(updatedProject);
    if (!_isNew) {
      context.read<ProjectTaskState>().updateProject(updatedProject);
    }
  }

  @override
  void didUpdateWidget(ProjectDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isOpen && oldWidget.isOpen) {
      _formCubit.cancelDelete();
    }
    if (widget.project != oldWidget.project ||
        widget.isOpen != oldWidget.isOpen) {
      _formCubit.cancelDelete();
      _formCubit.reset(_buildInitialDraft());
      _initControllers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFieldController.removeListener(_onNameEditModeChanged);
    _nameFieldController.dispose();
    _descriptionFieldController.removeListener(_onDescriptionEditModeChanged);
    _descriptionFieldController.dispose();
    _formCubit.close();
    super.dispose();
  }

  bool get _isNew => widget.project == null;

  void _handleSave() async {
    if (!_isNew) return;
    if (_nameController.text.isNotEmpty) {
      await context.read<ProjectTaskState>().createProject(
        _nameController.text,
        _descriptionController.text,
      );
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DrawerFormCubit<Project>, DrawerFormState<Project>>(
      bloc: _formCubit,
      builder: (context, formState) {
        final theme = context.theme;
        final palette = theme.colorsPalette;
        final isConfirmingDelete = formState.confirmingDelete;
        final projectTaskState = context.watch<ProjectTaskState>();
        final projectTasks = widget.project != null && !_isNew
            ? projectTaskState.tasks
                  .where((t) => t.projectId == widget.project!.id)
                  .toList()
            : <Task>[];

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
              if (!_isNew)
                DeleteConfirmationRow(
                  isShowing: isConfirmingDelete,
                  entityLabel: 'project',
                  onConfirm: () {
                    if (widget.project != null) {
                      context
                          .read<ProjectTaskState>()
                          .deleteProject(widget.project!.id);
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
                          status: widget.project!.status == ProjectStatus.done
                              ? BadgeStatus.done
                              : widget.project!.status == ProjectStatus.archived
                              ? BadgeStatus.ready
                              : BadgeStatus.inProgress,
                          statusLabel: _getStatusText(widget.project!.status),
                          createdAt: widget.project!.createdAt,
                        ),
                      ],
                      LabeledDivider(label: 'Assignment'),
                      SizedBox(height: theme.spacings.lg),
                      BaseCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InlineField(
                              label: 'Project name',
                              value: _nameController.text,
                              placeholder: 'Enter project name...',
                              controller: _nameFieldController,
                              textController: _nameController,
                              editWidget: PrimaryInput(
                                label: null,
                                hintText: 'Enter project name...',
                                controller: _nameController,
                                autofocus: true,
                              ),
                            ),
                            SizedBox(height: theme.spacings.lg),
                            InlineField(
                              label: 'Description',
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
                          LabeledDivider(label: 'Overview'),
                          SizedBox(height: theme.spacings.lg),
                          BaseCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricCard(
                                        title: 'TOTAL TIME',
                                        value:
                                            '${widget.project!.totalHours.toInt()}:15',
                                        unit: 'h',
                                        subtitle: '+12% from last week',
                                        subtitleColor: palette.accent.success,
                                        icon: Icons.trending_up,
                                      ),
                                    ),
                                    SizedBox(width: theme.spacings.lg),
                                    Expanded(
                                      child: _MetricCard(
                                        title: 'BILLABLE AMOUNT',
                                        value:
                                            '\$${_formatCurrency(widget.project!.billableAmount)}',
                                        subtitle:
                                            '\$${widget.project!.averageRate.toInt()}/hr average rate',
                                        subtitleColor: palette.text.secondary,
                                        icon: Icons.payments_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: theme.spacings.lg),
                                _MetricCard(
                                  title: 'BUDGET LEFT',
                                  value:
                                      '\$${_formatCurrency(widget.project!.budgetLeft)}',
                                  subtitle: 'Approaching limit',
                                  subtitleColor: palette.accent.danger,
                                  icon: Icons.warning_amber_rounded,
                                  fullWidth: true,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: theme.spacings.x3l),
                          LabeledDivider(label: 'Associated Tasks'),
                          SizedBox(height: theme.spacings.xl),
                          if (projectTasks.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: theme.spacings.xl,
                              ),
                              child: Center(
                                child: Text(
                                  'No tasks associated with this project yet.',
                                  style: theme.commonTextStyles.body.copyWith(
                                    color: palette.text.muted,
                                  ),
                                ),
                              ),
                            )
                          else
                            Column(
                              spacing: theme.spacings.lg,
                              children: projectTasks.map((task) {
                                final duration =
                                    context
                                        .watch<EntityResolver>()
                                        .getResolvedTask(task.id)
                                        ?.duration(DateTime.now()) ??
                                    Duration.zero;
                                return MasterListCard(
                                  title: task.title,
                                  metadata: _getTaskStatusText(task.status),
                                  trailing: Text(
                                    DateFormatter.formatDurationHms(duration),
                                    style: theme.commonTextStyles.bodyBold,
                                  ),
                                  onTap: () => context
                                      .read<AppNavigationController>()
                                      .openTask(task.id),
                                );
                              }).toList(),
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
      },
    );
  }

  String _getTaskStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return 'OPEN';
      case TaskStatus.done:
        return 'DONE';
      case TaskStatus.archived:
        return 'ARCHIVED';
    }
  }

  String _getStatusText(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.open:
        return 'OPEN';
      case ProjectStatus.done:
        return 'DONE';
      case ProjectStatus.archived:
        return 'ARCHIVED';
    }
  }

  String _formatCurrency(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? unit;
  final String subtitle;
  final Color subtitleColor;
  final IconData icon;
  final bool fullWidth;

  const _MetricCard({
    required this.title,
    required this.value,
    this.unit,
    required this.subtitle,
    required this.subtitleColor,
    required this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: EdgeInsets.all(theme.spacings.xl),
      decoration: BoxDecoration(
        color: palette.background.surfaceMuted,
        borderRadius: theme.radiuses.lg.circular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.commonTextStyles.caption3Bold.copyWith(
              color: palette.text.secondary,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: theme.spacings.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: theme.commonTextStyles.h1),
              if (unit != null) ...[
                SizedBox(width: theme.spacings.xxs),
                Text(
                  unit!,
                  style: theme.commonTextStyles.h3.copyWith(
                    color: palette.text.secondary,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: theme.spacings.lg),
          Row(
            children: [
              Icon(icon, color: subtitleColor, size: 14),
              SizedBox(width: theme.spacings.sm),
              Expanded(
                child: Text(
                  subtitle,
                  style: theme.commonTextStyles.caption.copyWith(
                    color: subtitleColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
