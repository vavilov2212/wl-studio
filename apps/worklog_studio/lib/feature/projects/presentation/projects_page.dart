import 'package:flutter/material.dart' hide DrawerControllerState;
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/resolved_project.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';
import 'components/project_card.dart';
import 'components/project_drawer.dart';
import 'package:worklog_studio/feature/common/presentation/drawer_controller_state.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'components/project_actions_cell.dart';

enum ProjectViewMode { cards, table }

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  DrawerControllerState<Project> _drawerState = DrawerControllerState.closed();
  ProjectViewMode _viewMode = ProjectViewMode.table;

  void _handleProjectSelected(Project project) {
    setState(() {
      if (_drawerState.state == DrawerState.edit &&
          _drawerState.entity?.id == project.id) {
        _drawerState = DrawerControllerState.closed();
      } else {
        _drawerState = DrawerControllerState.edit(project);
      }
    });
  }

  void _handleCreateProject() {
    setState(() {
      _drawerState = DrawerControllerState.create();
    });
  }

  void _closePanel() {
    setState(() {
      _drawerState = DrawerControllerState.closed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolver = context.watch<EntityResolver>();
    final resolvedProjects = resolver.getResolvedProjects();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ProjectList(
            projects: resolvedProjects,
            selectedProject: _drawerState.entity,
            onProjectSelected: _handleProjectSelected,
            onCreateProject: _handleCreateProject,
            viewMode: _viewMode,
            onViewModeChanged: (mode) => setState(() => _viewMode = mode),
          ),
        ),
        ProjectDrawer(
          project: _drawerState.entity,
          isOpen: _drawerState.isOpen,
          onClose: _closePanel,
        ),
      ],
    );
  }
}

class ProjectList extends StatelessWidget {
  final List<ResolvedProject> projects;
  final Project? selectedProject;
  final ValueChanged<Project> onProjectSelected;
  final VoidCallback onCreateProject;
  final ProjectViewMode viewMode;
  final ValueChanged<ProjectViewMode> onViewModeChanged;

  const ProjectList({
    super.key,
    required this.projects,
    required this.selectedProject,
    required this.onProjectSelected,
    required this.onCreateProject,
    required this.viewMode,
    required this.onViewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Padding(
      padding: EdgeInsets.all(theme.spacings.x2l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Projects',
                    style: theme.commonTextStyles.displayLarge,
                  ),
                  SizedBox(height: theme.spacings.xxs),
                  Text(
                    '${projects.length} currently in progress',
                    style: theme.commonTextStyles.body.copyWith(
                      color: palette.text.secondary,
                    ),
                  ),
                ],
              ),
              Row(
                spacing: theme.spacings.md,
                children: [
                  _ProjectViewModeToggle(
                    viewMode: viewMode,
                    onChanged: onViewModeChanged,
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.accent.primary,
                      borderRadius: theme.radiuses.sm.circular,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.add, color: palette.background.surface),
                      onPressed: onCreateProject,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: theme.spacings.x2l),
          Expanded(
            child: SingleChildScrollView(
              child: viewMode == ProjectViewMode.table
                  ? WsTable<ResolvedProject>(
                      data: projects,
                      selectedItem: projects.firstWhereOrNull(
                        (e) => e.id == selectedProject?.id,
                      ),
                      onRowTap: (item) => onProjectSelected(item.project),
                      isSelected: (item, selected) => item.id == selected?.id,
                      columns: _getTableColumns(theme),
                    )
                  : Column(
                      spacing: theme.spacings.lg,
                      children: projects.map((project) {
                        final isSelected = selectedProject?.id == project.id;
                        return ProjectCard(
                          project: project,
                          isSelected: isSelected,
                          onTap: () => onProjectSelected(project.project),
                        );
                      }).toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<WsTableColumn<ResolvedProject>> _getTableColumns(
    AppThemeExtension theme,
  ) {
    return [
      WsTableColumn(
        title: 'Project',
        flex: 3,
        builder: (context, item, isHovered) {
          final palette = theme.colorsPalette;
          final initials = BadgeUtils.getProjectInitials(item.name);
          final colors = BadgeUtils.getBadgeColor(item.id);

          return Row(
            children: [
              WsInitialBadge(
                initials: initials,
                backgroundColor: colors.$1,
                textColor: colors.$2,
              ),
              SizedBox(width: theme.spacings.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: theme.commonTextStyles.bodyBold.copyWith(
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.project.clientName.isNotEmpty)
                      Text(
                        item.project.clientName,
                        style: theme.commonTextStyles.caption.copyWith(
                          color: palette.text.secondary,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      WsTableColumn(
        title: 'Description',
        flex: 3,
        builder: (context, item, isHovered) {
          final palette = theme.colorsPalette;
          return Text(
            item.project.description.isEmpty
                ? 'No description'
                : item.project.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.commonTextStyles.body2.copyWith(
              color: item.project.description.isEmpty
                  ? palette.text.secondary.withValues(alpha: 0.5)
                  : palette.text.secondary,
            ),
          );
        },
      ),
      WsTableColumn(
        title: 'Time Tracked',
        flex: 2,
        builder: (context, item, isHovered) {
          final isActive = context.select<TimeTrackerBloc, bool>(
            (bloc) => bloc.state.activeEntryOrNull?.projectId == item.id,
          );

          if (isActive) {
            return LiveDurationText(
              durationBuilder: (now) => item.duration(now),
              style: theme.commonTextStyles.bodyBold.copyWith(
                color: theme.colorsPalette.accent.primary,
              ),
            );
          }

          final duration = item.duration(DateTime.now());
          return Text(
            _formatExactDuration(duration),
            style: theme.commonTextStyles.bodyBold,
          );
        },
      ),
      WsTableColumn(
        title: 'Status',
        flex: 1,
        builder: (context, item, isHovered) {
          final isActive = context.select<TimeTrackerBloc, bool>(
            (bloc) => bloc.state.activeEntryOrNull?.projectId == item.id,
          );

          if (isActive) {
            return const Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(
                status: BadgeStatus.inProgress,
                label: 'RUNNING',
              ),
            );
          }

          return Align(
            alignment: Alignment.centerLeft,
            child: StatusBadge(
              status: _getBadgeStatus(item.status),
              label: item.status.name.toUpperCase(),
            ),
          );
        },
      ),
      WsTableColumn(
        title: 'Actions',
        alignment: Alignment.centerRight,

        flex: 1,
        builder: (context, item, isHovered) {
          return ProjectActionsCell(project: item, isHovered: isHovered);
        },
      ),
    ];
  }

  BadgeStatus _getBadgeStatus(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.open:
        return BadgeStatus.inProgress;
      case ProjectStatus.done:
        return BadgeStatus.ready;
      case ProjectStatus.archived:
        return BadgeStatus.done;
    }
  }

  String _formatExactDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _ProjectViewModeToggle extends StatelessWidget {
  final ProjectViewMode viewMode;
  final ValueChanged<ProjectViewMode> onChanged;

  const _ProjectViewModeToggle({
    required this.viewMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      decoration: BoxDecoration(
        color: palette.background.surface,
        borderRadius: theme.radiuses.sm.circular,
        border: Border.all(
          color: palette.border.primary.withValues(alpha: 0.5),
        ),
      ),
      padding: EdgeInsets.all(theme.spacings.xxs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(
            context,
            icon: Icons.grid_view_rounded,
            isSelected: viewMode == ProjectViewMode.cards,
            onTap: () => onChanged(ProjectViewMode.cards),
          ),
          SizedBox(width: theme.spacings.xxs),
          _buildToggleButton(
            context,
            icon: Icons.table_rows_rounded,
            isSelected: viewMode == ProjectViewMode.table,
            onTap: () => onChanged(ProjectViewMode.table),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(
    BuildContext context, {
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Material(
      color: isSelected ? palette.background.surface : Colors.transparent,
      borderRadius: theme.radiuses.sm.circular,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(theme.spacings.sm),
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(
                    color: palette.border.primary.withValues(alpha: 0.5),
                  )
                : Border.all(color: Colors.transparent),
            borderRadius: theme.radiuses.sm.circular,
            boxShadow: isSelected ? [theme.shadows.sm] : null,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? palette.text.primary : palette.text.secondary,
          ),
        ),
      ),
    );
  }
}
