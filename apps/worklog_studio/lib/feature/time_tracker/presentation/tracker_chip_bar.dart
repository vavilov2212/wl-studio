import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vector_svg/vector_svg.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/tracker_panel_cubit.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/active_timer_text.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class TrackerChipBar extends StatelessWidget {
  final bool isPanelOpen;
  final VoidCallback onOpenPanel;
  final ValueChanged<String> onOpenProject;
  final ValueChanged<String> onOpenTask;

  const TrackerChipBar({
    super.key,
    required this.isPanelOpen,
    required this.onOpenPanel,
    required this.onOpenProject,
    required this.onOpenTask,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return BlocBuilder<TimeTrackerBloc, TimeTrackerBlocState>(
      buildWhen: (prev, curr) =>
          prev.isRunning != curr.isRunning ||
          prev.activeEntryOrNull != curr.activeEntryOrNull,
      builder: (context, state) {
        if (state.isRunning) {
          return _buildRunningChip(context, state, theme, palette, isWide);
        }
        return _buildIdleChip(context, theme, palette, isWide);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Idle state - compact single row
  // ---------------------------------------------------------------------------

  Widget _buildIdleChip(
    BuildContext context,
    AppThemeExtension theme,
    ColorsPalette palette,
    bool isWide,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpenPanel,
      child: Container(
        width: double.infinity,
        height: isWide ? 36.0 : 40.0,
        decoration: _decoration(palette),
        padding: EdgeInsets.symmetric(horizontal: theme.spacings.x2l),
        child: Row(
          children: [
            WorklogStudioAssets.vectors.playFilled64Svg.vector(
              width: 14,
              height: 14,
              colorFilter: palette.text.muted.filter,
            ),
            SizedBox(width: theme.spacings.sm),
            Text(
              'Start tracking...', // TODO: l10n
              style: theme.commonTextStyles.body
                  .copyWith(color: palette.text.muted),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Running state - two-row layout: project/task + comment, timer on the right
  // ---------------------------------------------------------------------------

  Widget _buildRunningChip(
    BuildContext context,
    TimeTrackerBlocState state,
    AppThemeExtension theme,
    ColorsPalette palette,
    bool isWide,
  ) {
    final projectTaskState = context.read<ProjectTaskState>();
    final activeEntry = state.activeEntryOrNull;

    final project = projectTaskState.projects
        .firstWhereOrNull((p) => p.id == activeEntry?.projectId);
    final task = projectTaskState.tasks
        .firstWhereOrNull((t) => t.id == activeEntry?.taskId);
    final comment = activeEntry?.comment ?? '';
    final hasComment = comment.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpenPanel,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: isWide ? 36.0 : 40.0),
        decoration: _decoration(palette),
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacings.x2l,
          vertical: theme.spacings.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Badge anchors the left edge
            if (project != null) ...[
              WsInitialBadge(
                initials: BadgeUtils.getProjectInitials(project.name),
                backgroundColor: BadgeUtils.getBadgeColor(project.id).$1,
                textColor: BadgeUtils.getBadgeColor(project.id).$2,
                size: WsInitialBadgeSize.small,
              ),
              SizedBox(width: theme.spacings.sm),
            ],

            // Info column - takes all remaining space
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: project / task
                  Row(
                    children: [
                      if (project != null)
                        Flexible(
                          child: Text(
                            project.name,
                            style: theme.commonTextStyles.body2.copyWith(
                              color: palette.text.secondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (task != null) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: theme.spacings.xxs,
                          ),
                          child: Text(
                            '/',
                            style: theme.commonTextStyles.body2.copyWith(
                              color: palette.text.muted,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            task.title,
                            style: theme.commonTextStyles.body2Bold.copyWith(
                              color: palette.text.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Row 2: comment (only when present)
                  if (hasComment) ...[
                    const SizedBox(height: 2),
                    Text(
                      comment,
                      style: theme.commonTextStyles.caption.copyWith(
                        color: palette.text.muted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Timer + stop pinned to the right
            SizedBox(width: theme.spacings.md),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ActiveTimerText(
                  style: theme.commonTextStyles.body.copyWith(
                    color: palette.text.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(width: theme.spacings.sm),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.read<TrackerPanelCubit>().stopTimer(),
                  child: WorklogStudioAssets.vectors.squareFilled64Svg.vector(
                    width: 14,
                    height: 14,
                    colorFilter: palette.accent.danger.filter,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _decoration(ColorsPalette palette) => BoxDecoration(
        color: palette.background.surface,
        border: Border(
          bottom: BorderSide(
            color: isPanelOpen ? palette.border.hover : palette.border.primary,
          ),
        ),
      );
}
