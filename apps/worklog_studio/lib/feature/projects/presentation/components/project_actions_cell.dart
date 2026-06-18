import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/domain/resolved_project.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class ProjectActionsCell extends StatelessWidget {
  final ResolvedProject project;

  const ProjectActionsCell({
    super.key,
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    // Assuming we can check if it's currently running via bloc state
    final isRunningThis = context.select<TimeTrackerBloc, bool>(
      (bloc) =>
          bloc.state.isRunning &&
          bloc.state.activeEntryOrNull?.projectId == project.id,
    );

    if (isRunningThis) {
      return PrimaryButton(
        type: ButtonType.danger,
        size: ButtonSize.sm,
        leftIcon: WorklogStudioAssets.vectors.squareFilled64Svg,
        onTap: () {
          context.read<TimeTrackerBloc>().add(TimeTrackerStopped());
        },
      );
    } else {
      return PrimaryButton(
        type: ButtonType.ghost,
        size: ButtonSize.sm,
        leftIcon: WorklogStudioAssets.vectors.playFilled64Svg,
        onTap: () {
          context.read<TimeTrackerBloc>().add(
            TimeTrackerStarted(
              projectId: project.id,
              taskId: null,
              comment: '',
            ),
          );
        },
      );
    }
  }
}
