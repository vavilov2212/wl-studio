import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/feature/projects/presentation/components/project_list.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/page_ui_preferences.dart';

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
    final prefs = context.watch<PageUiPreferences>();
    final drawer = context.watch<DrawerHostController>();
    final selectedProject =
        drawer.kind == DrawerEntityKind.project ? drawer.project : null;
    final isFilterExpanded =
        prefs.projectsFilterExpandedOverride ?? prefs.projectsFilters.isActive;
    final isSortExpanded = prefs.projectsSortExpandedOverride ?? false;

    return ProjectList(
      projects: resolvedProjects,
      selectedProject: selectedProject,
      selectedRowKey: _selectedRowKey,
      onProjectSelected: _handleProjectSelected,
      onCreateProject: _handleCreateProject,
      viewMode: prefs.projectsViewMode,
      onViewModeChanged: (mode) =>
          context.read<PageUiPreferences>().setProjectsViewMode(mode),
      filters: prefs.projectsFilters,
      onFiltersChanged: (f) =>
          context.read<PageUiPreferences>().setProjectsFilters(f),
      isFilterExpanded: isFilterExpanded,
      onFilterExpandedToggle: () => context
          .read<PageUiPreferences>()
          .setProjectsFilterExpandedOverride(!isFilterExpanded),
      sortField: prefs.projectsSortField,
      sortDirection: prefs.projectsSortDirection,
      onSortFieldChanged: (field) =>
          context.read<PageUiPreferences>().setProjectsSortField(field),
      onSortDirectionChanged: (direction) =>
          context.read<PageUiPreferences>().setProjectsSortDirection(direction),
      isSortExpanded: isSortExpanded,
      onSortExpandedToggle: () => context
          .read<PageUiPreferences>()
          .setProjectsSortExpandedOverride(!isSortExpanded),
    );
  }
}
