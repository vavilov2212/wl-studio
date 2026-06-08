import 'package:flutter/material.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/resolved_project.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/common/presentation/interactive_card.dart';
import 'package:worklog_studio/feature/common/presentation/components/card_row.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';

class ProjectCard extends StatelessWidget {
  final ResolvedProject project;
  final bool isSelected;
  final VoidCallback onTap;

  const ProjectCard({
    super.key,
    required this.project,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return InteractiveCard(
      isSelected: isSelected,
      onTap: onTap,
      child: CardRow(
        columns: [
          CardColumn(
            flex: 3,
            child: Row(
              children: [
                Builder(
                  builder: (context) {
                    final initials = BadgeUtils.getProjectInitials(
                      project.name,
                    );
                    final colors = BadgeUtils.getBadgeColor(project.id);
                    return WsInitialBadge(
                      initials: initials,
                      backgroundColor: colors.$1,
                      textColor: colors.$2,
                    );
                  },
                ),
                SizedBox(width: theme.spacings.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        project.name,
                        style: theme.commonTextStyles.bodyBold.copyWith(
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (project.project.clientName.isNotEmpty)
                        Text(
                          project.project.clientName,
                          style: theme.commonTextStyles.caption.copyWith(
                            color: palette.text.secondary,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      SizedBox(height: theme.spacings.sm),
                      LinearProgressIndicator(
                        value: project.project.budgetUtilization,
                        backgroundColor: palette.border.primary,
                        color: palette.accent.primary,
                        minHeight: 4,
                        borderRadius: theme.radiuses.pill.circular,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          CardColumn(
            flex: 4,
            child: Text(
              project.description.isEmpty
                  ? 'No description'
                  : project.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: project.status == ProjectStatus.done
                  ? theme.commonTextStyles.caption.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: palette.text.secondary.withValues(alpha: 0.5),
                    )
                  : theme.commonTextStyles.caption.copyWith(
                      color: project.description.isEmpty
                          ? palette.text.secondary.withValues(alpha: 0.5)
                          : palette.text.secondary,
                    ),
            ),
          ),
          CardColumn(
            flex: 1,
            alignment: Alignment.centerRight,
            child: Builder(
              builder: (context) {
                final isActive = context.select<TimeTrackerBloc, bool>(
                  (bloc) =>
                      bloc.state.activeEntryOrNull?.projectId == project.id,
                );
                if (isActive) {
                  return Text(
                    'RUNNING',
                    style: theme.commonTextStyles.caption3Bold.copyWith(
                      color: palette.accent.primary,
                      letterSpacing: 1.0,
                    ),
                  );
                }
                return Text(
                  getStatusText(project.status),
                  style: theme.commonTextStyles.caption3Bold.copyWith(
                    color: palette.text.muted,
                    letterSpacing: 1.0,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
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
