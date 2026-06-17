import 'package:flutter/material.dart' hide DrawerHeader;
import 'package:provider/provider.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field_controller.dart';
import 'package:worklog_studio/feature/common/presentation/resizable_drawer.dart';
import 'package:worklog_studio/feature/common/presentation/components/drawer_content.dart';
import 'package:worklog_studio/feature/common/presentation/components/drawer_header.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/feature/common/presentation/components/entity_meta_info_row.dart';

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
  bool _isConfirmingDelete = false;
  late Project _draft;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final InlineFieldController _nameFieldController = InlineFieldController();
  final InlineFieldController _descriptionFieldController =
      InlineFieldController();

  @override
  void initState() {
    super.initState();
    _initDraft();
    _initControllers();
  }

  void _initDraft() {
    if (widget.project != null) {
      _draft = widget.project!;
    } else {
      _draft = Project(
        id: '',
        name: '',
        description: '',
        createdAt: DateTime.now(),
        status: ProjectStatus.open,
      );
    }
  }

  void _initControllers() {
    _nameController = TextEditingController(text: _draft.name);
    _descriptionController = TextEditingController(text: _draft.description);
  }

  @override
  void didUpdateWidget(ProjectDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isOpen && oldWidget.isOpen) {
      _isConfirmingDelete = false;
    }
    if (widget.project != oldWidget.project ||
        widget.isOpen != oldWidget.isOpen) {
      _initDraft();
      _initControllers();
    }
  }

  bool get _isNew => widget.project == null;

  void _handleSave() async {
    final state = context.read<ProjectTaskState>();

    if (_isNew) {
      if (_nameController.text.isNotEmpty) {
        await state.createProject(
          _nameController.text,
          _descriptionController.text,
        );
        widget.onClose();
      }
    } else {
      if (_nameController.text.isNotEmpty) {
        final updatedProject = _draft.copyWith(
          name: _nameController.text,
          description: _descriptionController.text,
        );
        await state.updateProject(updatedProject);
        widget.onClose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final projectTaskState = context.watch<ProjectTaskState>();
    final projectTasks = widget.project != null && !_isNew
        ? projectTaskState.tasks
              .where((t) => t.projectId == widget.project!.id)
              .toList()
        : [];

    return ResizableDrawer(
      isOpen: widget.isOpen,
      onClose: widget.onClose,
      mode: widget.mode,
      header: DrawerHeader(
        onClose: widget.onClose,
        onDelete: _isNew
            ? null
            : () {
                setState(() {
                  _isConfirmingDelete = true;
                });
              },
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
                              theme.spacings.x2l,
                              theme.spacings.lg,
                              theme.spacings.x2l,
                              0,
                            ),
                            child: InfoBar(
                              variant: InfoBarVariant.danger,
                              title: const Text('Delete this project?'),
                              description: const Text(
                                'This action cannot be undone',
                              ),
                              actions: Wrap(
                                spacing: theme.spacings.sm,
                                runSpacing: theme.spacings.sm,
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  PrimaryButton(
                                    onTap: () {
                                      if (widget.project != null) {
                                        context
                                            .read<ProjectTaskState>()
                                            .deleteProject(widget.project!.id);
                                        widget.onClose();
                                      }
                                    },
                                    title: 'Delete',
                                    type: ButtonType.danger,
                                    size: ButtonSize.sm,
                                  ),
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
                Expanded(
                  child: DrawerContent(
                    meta: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_isNew) ...[
                          EntityMetaInfoRow(
                            status: widget.project!.status == ProjectStatus.done
                                ? BadgeStatus.done
                                : widget.project!.status ==
                                      ProjectStatus.archived
                                ? BadgeStatus.ready
                                : BadgeStatus.inProgress,
                            statusLabel: getStatusText(widget.project!.status),
                            createdAt: widget.project!.createdAt,
                          ),
                        ],
                        // Name Input
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
                          SizedBox(height: theme.spacings.x2l),
                          LabeledDivider(label: 'Notes'),
                          SizedBox(height: theme.spacings.lg),
                          InlineField(
                            label: 'Description',
                            value: _descriptionController.text,
                            placeholder: 'Add a description...',
                            controller: _descriptionFieldController,
                            textController: _descriptionController,
                            isTextArea: true,
                            editWidget: TextArea(
                              label: null,
                              hintText: 'Add a description...',
                              controller: _descriptionController,
                              autofocus: true,
                            ),
                          ),
                          if (!_isNew) ...[
                            SizedBox(height: theme.spacings.x2l),
                            LabeledDivider(label: 'Overview'),
                            SizedBox(height: theme.spacings.lg),
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
                            SizedBox(height: theme.spacings.x3l),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Associated Tasks',
                                  style: theme.commonTextStyles.h3,
                                ),
                                Text(
                                  'VIEW ALL',
                                  style: theme.commonTextStyles.caption3Bold
                                      .copyWith(color: palette.accent.primary),
                                ),
                              ],
                            ),
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
                                  return Container(
                                    padding: EdgeInsets.all(theme.spacings.lg),
                                    decoration: BoxDecoration(
                                      color: palette.background.surfaceMuted,
                                      borderRadius: theme.radiuses.md.circular,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(
                                            theme.spacings.sm,
                                          ),
                                          decoration: BoxDecoration(
                                            color: palette.background.surface,
                                            borderRadius:
                                                theme.radiuses.sm.circular,
                                          ),
                                          child: Icon(
                                            Icons.task_alt, // Default icon
                                            color: palette.accent.primary,
                                            size: 20,
                                          ),
                                        ),
                                        SizedBox(width: theme.spacings.lg),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                task.title,
                                                style: theme
                                                    .commonTextStyles
                                                    .bodyBold,
                                              ),
                                              SizedBox(
                                                height: theme.spacings.xxs,
                                              ),
                                              Text(
                                                getStatusText(
                                                  widget.project!.status,
                                                ),
                                                style: theme
                                                    .commonTextStyles
                                                    .caption
                                                    .copyWith(
                                                      color: palette
                                                          .text
                                                          .secondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '0:00h', // Default time
                                          style:
                                              theme.commonTextStyles.bodyBold,
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                          SizedBox(
                            height: theme.spacings.xl,
                          ), // Bottom padding for scroll
                        ],
                      ),
                    ),
                    footer: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                            title: _isNew ? 'Create Project' : 'Save Changes',
                            size: ButtonSize.lg,
                            onTap: _handleSave,
                          ),
                        ),
                        if (!_isNew) ...[
                          SizedBox(height: theme.spacings.lg),
                          SizedBox(
                            width: double.infinity,
                            child: PrimaryButton(
                              title: 'Add Task',
                              type: ButtonType.secondary,
                              leftIcon: WorklogStudioAssets.vectors.plus24Svg,
                              onTap: () {},
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String getStatusText(ProjectStatus status) {
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
