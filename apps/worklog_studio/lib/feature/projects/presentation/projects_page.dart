import 'package:flutter/material.dart' hide DrawerControllerState;
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/resolved_project.dart';
import 'package:worklog_studio/domain/projects_filters.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';
import 'components/project_card.dart';
import 'components/project_drawer.dart';
import 'components/projects_filter_bar.dart';
import 'package:worklog_studio/feature/common/presentation/drawer_controller_state.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'components/project_actions_cell.dart';

enum ProjectViewMode { cards, table }

class ProjectsScreen extends StatefulWidget {
  final String? initialSelectedProjectId;

  const ProjectsScreen({super.key, this.initialSelectedProjectId});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  DrawerControllerState<Project> _drawerState = DrawerControllerState.closed();
  ProjectViewMode _viewMode = ProjectViewMode.table;
  ProjectsFilters _filters = const ProjectsFilters();
  bool? _filterExpandedOverride;
  bool get _isFilterExpanded => _filterExpandedOverride ?? _filters.isActive;
  final GlobalKey _selectedRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedProjectId != null) {
      _selectProjectById(widget.initialSelectedProjectId!);
    }
  }

  @override
  void didUpdateWidget(covariant ProjectsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedProjectId != null &&
        widget.initialSelectedProjectId != oldWidget.initialSelectedProjectId) {
      _selectProjectById(widget.initialSelectedProjectId!);
    }
  }

  void _selectProjectById(String projectId) {
    final resolvedProject = context
        .read<EntityResolver>()
        .getResolvedProjects()
        .firstWhereOrNull((p) => p.id == projectId);
    if (resolvedProject != null) {
      setState(() {
        _drawerState = DrawerControllerState.edit(resolvedProject.project);
      });
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
            selectedRowKey: _selectedRowKey,
            onProjectSelected: _handleProjectSelected,
            onCreateProject: _handleCreateProject,
            viewMode: _viewMode,
            onViewModeChanged: (mode) => setState(() => _viewMode = mode),
            filters: _filters,
            onFiltersChanged: (f) => setState(() => _filters = f),
            isFilterExpanded: _isFilterExpanded,
            onFilterExpandedToggle: () =>
                setState(() => _filterExpandedOverride = !_isFilterExpanded),
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
  final GlobalKey? selectedRowKey;
  final ValueChanged<Project> onProjectSelected;
  final VoidCallback onCreateProject;
  final ProjectViewMode viewMode;
  final ValueChanged<ProjectViewMode> onViewModeChanged;
  final ProjectsFilters filters;
  final ValueChanged<ProjectsFilters> onFiltersChanged;
  final bool isFilterExpanded;
  final VoidCallback onFilterExpandedToggle;

  const ProjectList({
    super.key,
    required this.projects,
    required this.selectedProject,
    this.selectedRowKey,
    required this.onProjectSelected,
    required this.onCreateProject,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.filters,
    required this.onFiltersChanged,
    required this.isFilterExpanded,
    required this.onFilterExpandedToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Padding(
      padding: EdgeInsets.all(theme.spacings.x2l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Active Projects', style: theme.commonTextStyles.h3),
              Row(
                spacing: theme.spacings.md,
                children: [
                  SegmentedToggle<ProjectViewMode>(
                    value: viewMode,
                    onChanged: onViewModeChanged,
                    options: const [
                      SegmentedToggleOption(
                        value: ProjectViewMode.cards,
                        icon: Icons.grid_view_rounded,
                      ),
                      SegmentedToggleOption(
                        value: ProjectViewMode.table,
                        icon: Icons.table_rows_rounded,
                      ),
                    ],
                  ),
                  PrimaryButton(
                    title: 'New Project',
                    leftIcon: WorklogStudioAssets.vectors.plus24Svg,
                    size: ButtonSize.sm,
                    onTap: onCreateProject,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: theme.spacings.lg),
          TableToolbar(
            isFilterExpanded: isFilterExpanded,
            onFilterTap: onFilterExpandedToggle,
            activeFilterCount: filters.activeCount,
          ),
          if (isFilterExpanded) ...[
            SizedBox(height: theme.spacings.sm),
            ProjectsFilterBar(filters: filters, onChanged: onFiltersChanged),
          ],
          SizedBox(height: theme.spacings.x2l),
          Expanded(
            child: SingleChildScrollView(
              child: () {
                final filteredProjects = applyProjectsFilters(projects, filters);
                return viewMode == ProjectViewMode.table
                    ? WsTable<ResolvedProject>(
                        data: filteredProjects,
                        selectedItem: filteredProjects.firstWhereOrNull(
                          (e) => e.id == selectedProject?.id,
                        ),
                        rowKeyBuilder: (item) =>
                            item.id == selectedProject?.id ? selectedRowKey : null,
                        onRowTap: (item) => onProjectSelected(item.project),
                        isSelected: (item, selected) => item.id == selected?.id,
                        columns: _getTableColumns(theme),
                      )
                    : Column(
                        spacing: theme.spacings.lg,
                        children: filteredProjects.map((project) {
                          final isSelected = selectedProject?.id == project.id;
                          return ProjectCard(
                            key: isSelected ? selectedRowKey : null,
                            project: project,
                            isSelected: isSelected,
                            onTap: () => onProjectSelected(project.project),
                          );
                        }).toList(),
                      );
              }(),
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
                size: WsInitialBadgeSize.small,
              ),
              SizedBox(width: theme.spacings.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.commonTextStyles.labelMedium,
                    ),
                    if (item.project.clientName.isNotEmpty)
                      Text(
                        item.project.clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.commonTextStyles.caption.copyWith(
                          color: palette.text.secondary,
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
        flex: 8,
        builder: (context, item, isHovered) {
          final palette = theme.colorsPalette;
          return Text(
            item.project.description.isEmpty
                ? 'No description'
                : item.project.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
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
              style: theme.commonTextStyles.labelMedium.copyWith(
                color: theme.colorsPalette.accent.primary,
              ),
            );
          }

          final duration = item.duration(DateTime.now());
          return Text(
            _formatExactDuration(duration),
            style: theme.commonTextStyles.labelMedium,
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
        builder: (context, item, _) {
          return ProjectActionsCell(project: item);
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

