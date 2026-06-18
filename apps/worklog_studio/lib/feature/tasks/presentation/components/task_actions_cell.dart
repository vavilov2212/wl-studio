import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/domain/resolved_task.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class TaskActionsCell extends StatelessWidget {
  final ResolvedTask task;

  const TaskActionsCell({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    // Check if this task is currently running
    final isRunningThis = context.select<TimeTrackerBloc, bool>(
      (bloc) =>
          bloc.state.isRunning &&
          bloc.state.activeEntryOrNull?.taskId == task.id,
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
              projectId: task.task.projectId,
              taskId: task.id,
              comment: '',
            ),
          );
        },
      );
    }
  }
}
