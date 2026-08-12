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

    return Container(
      width: double.infinity,
      height: isWide ? 36.0 : 40.0,
      decoration: BoxDecoration(
        color: palette.background.surface,
        border: Border(
          bottom: BorderSide(
            color: isPanelOpen
                ? palette.border.hover
                : palette.border.primary,
          ),
        ),
      ),
      child: BlocBuilder<TimeTrackerBloc, TimeTrackerBlocState>(
        buildWhen: (prev, curr) =>
            prev.isRunning != curr.isRunning ||
            prev.activeEntryOrNull != curr.activeEntryOrNull,
        builder: (context, state) {
          if (state.isRunning) {
            return _buildRunningChip(context, theme, palette);
          }
          return _buildIdleChip(context, theme, palette);
        },
      ),
    );
  }

  Widget _buildIdleChip(
    BuildContext context,
    AppThemeExtension theme,
    ColorsPalette palette,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpenPanel,
      child: Padding(
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

  Widget _buildRunningChip(
    BuildContext context,
    AppThemeExtension theme,
    ColorsPalette palette,
  ) {
    final projectTaskState = context.read<ProjectTaskState>();
    final draftProjectId = context.select<ProjectTaskState, String?>(
      (s) => s.draftProjectId,
    );
    final draftTaskId = context.select<ProjectTaskState, String?>(
      (s) => s.draftTaskId,
    );
    final project = projectTaskState.projects
        .firstWhereOrNull((p) => p.id == draftProjectId);
    final task =
        projectTaskState.tasks.firstWhereOrNull((t) => t.id == draftTaskId);

    final dot = Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacings.sm),
      child: Text(
        '·',
        style: theme.commonTextStyles.body.copyWith(color: palette.text.muted),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpenPanel,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.spacings.x2l),
        child: Row(
          children: [
            if (project != null) ...[
              WsInitialBadge(
                initials: BadgeUtils.getProjectInitials(project.name),
                backgroundColor: BadgeUtils.getBadgeColor(project.id).$1,
                textColor: BadgeUtils.getBadgeColor(project.id).$2,
                size: WsInitialBadgeSize.small,
              ),
              SizedBox(width: theme.spacings.sm),
              Text(
                project.name,
                style: theme.commonTextStyles.body
                    .copyWith(color: palette.text.secondary),
              ),
            ],
            if (task != null) ...[
              dot,
              Text(
                task.title,
                style: theme.commonTextStyles.body
                    .copyWith(color: palette.text.secondary),
              ),
            ],
            dot,
            ActiveTimerText(
              style: theme.commonTextStyles.body.copyWith(
                color: palette.text.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            dot,
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
      ),
    );
  }
}
