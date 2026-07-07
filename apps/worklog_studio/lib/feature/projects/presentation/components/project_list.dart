import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/projects_filters.dart';
import 'package:worklog_studio/domain/projects_sort.dart';
import 'package:worklog_studio/domain/resolved_project.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/feature/projects/presentation/components/project_card.dart';
import 'package:worklog_studio/feature/projects/presentation/components/project_table.dart';
import 'package:worklog_studio/feature/projects/presentation/components/projects_filter_bar.dart';
import 'package:worklog_studio/feature/projects/presentation/components/projects_sort_bar.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

enum ProjectViewMode { cards, table }

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
  final ProjectsSortField sortField;
  final SortDirection sortDirection;
  final ValueChanged<ProjectsSortField> onSortFieldChanged;
  final ValueChanged<SortDirection> onSortDirectionChanged;
  final bool isSortExpanded;
  final VoidCallback onSortExpandedToggle;

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
    required this.sortField,
    required this.sortDirection,
    required this.onSortFieldChanged,
    required this.onSortDirectionChanged,
    required this.isSortExpanded,
    required this.onSortExpandedToggle,
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
            isSortExpanded: isSortExpanded,
            onSortTap: onSortExpandedToggle,
          ),
          if (isFilterExpanded) ...[
            SizedBox(height: theme.spacings.sm),
            ProjectsFilterBar(filters: filters, onChanged: onFiltersChanged),
          ],
          if (isSortExpanded) ...[
            SizedBox(height: theme.spacings.sm),
            ProjectsSortBar(
              field: sortField,
              direction: sortDirection,
              onFieldChanged: onSortFieldChanged,
              onDirectionChanged: onSortDirectionChanged,
            ),
          ],
          SizedBox(height: theme.spacings.x2l),
          Expanded(
            child: SingleChildScrollView(
              child: () {
                final filteredProjects = applyProjectsSort(
                  applyProjectsFilters(projects, filters),
                  sortField,
                  sortDirection,
                );
                return viewMode == ProjectViewMode.table
                    ? WsTable<ResolvedProject>(
                        data: filteredProjects,
                        selectedItem: filteredProjects.firstWhereOrNull(
                          (e) => e.id == selectedProject?.id,
                        ),
                        rowKeyBuilder: (item) =>
                            item.id == selectedProject?.id
                                ? selectedRowKey
                                : null,
                        onRowTap: (item) => onProjectSelected(item.project),
                        isSelected: (item, selected) =>
                            item.id == selected?.id,
                        columns: getProjectTableColumns(theme),
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
}
