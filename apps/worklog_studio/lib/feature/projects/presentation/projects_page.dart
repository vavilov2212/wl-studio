import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/feature/projects/bloc/projects_bloc.dart';
import 'package:worklog_studio/feature/projects/presentation/components/project_list.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
import 'package:worklog_studio/state/entity_resolver.dart';

export 'package:worklog_studio/feature/projects/presentation/components/project_list.dart'
    show ProjectViewMode;

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final GlobalKey _selectedRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final drawer = context.read<DrawerHostController>();
    if (drawer.kind == DrawerEntityKind.project && drawer.project != null) {
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
    final drawer = context.read<DrawerHostController>();
    if (drawer.kind == DrawerEntityKind.project &&
        drawer.project?.id == project.id) {
      drawer.close();
    } else {
      drawer.openProjectEdit(project);
    }
  }

  void _handleCreateProject() {
    context.read<DrawerHostController>().openProjectCreate();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedProjects = context
        .watch<EntityResolver>()
        .getResolvedProjects();
    final drawer = context.watch<DrawerHostController>();
    final selectedProject =
        drawer.kind == DrawerEntityKind.project ? drawer.project : null;

    return BlocBuilder<ProjectsBloc, ProjectsState>(
      builder: (context, projectsState) {
        final isFilterExpanded =
            projectsState.filterExpandedOverride ??
            projectsState.filters.isActive;
        final isSortExpanded = projectsState.sortExpanded;

        return ProjectList(
          projects: resolvedProjects,
          selectedProject: selectedProject,
          selectedRowKey: _selectedRowKey,
          onProjectSelected: _handleProjectSelected,
          onCreateProject: _handleCreateProject,
          viewMode: projectsState.viewMode,
          onViewModeChanged: (mode) =>
              context.read<ProjectsBloc>().add(ProjectsViewModeChanged(mode)),
          filters: projectsState.filters,
          onFiltersChanged: (f) =>
              context.read<ProjectsBloc>().add(ProjectsFilterChanged(f)),
          isFilterExpanded: isFilterExpanded,
          onFilterExpandedToggle: () => context.read<ProjectsBloc>().add(
            ProjectsFilterExpandedOverrideSet(!isFilterExpanded),
          ),
          sortField: projectsState.sortField,
          sortDirection: projectsState.sortDirection,
          onSortFieldChanged: (field) =>
              context.read<ProjectsBloc>().add(ProjectsSortFieldChanged(field)),
          onSortDirectionChanged: (direction) => context.read<ProjectsBloc>().add(
            ProjectsSortDirectionChanged(direction),
          ),
          isSortExpanded: isSortExpanded,
          onSortExpandedToggle: () => context.read<ProjectsBloc>().add(
            ProjectsSortExpandedSet(!isSortExpanded),
          ),
        );
      },
    );
  }
}
