import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class TimeEntryActionsCell extends StatelessWidget {
  final ResolvedTimeEntry resolvedEntry;
  final bool isHovered;

  const TimeEntryActionsCell({
    super.key,
    required this.resolvedEntry,
    required this.isHovered,
  });

  @override
  Widget build(BuildContext context) {
    final entry = resolvedEntry.entry;

    final isRunningThis = context.select<TimeTrackerBloc, bool>(
      (bloc) =>
          bloc.state.isRunning && bloc.state.activeEntryOrNull?.id == entry.id,
    );

    if (isRunningThis) {
      return PrimaryButton(
        initialAnimationDuration: Duration(milliseconds: 20),
        type: isHovered ? ButtonType.danger : ButtonType.primary,
        size: ButtonSize.sm,
        leftIcon: WorklogStudioAssets.vectors.squareFilled24Svg,
        onTap: () {
          context.read<TimeTrackerBloc>().add(TimeTrackerStopped());
        },
      );
    } else {
      return PrimaryButton(
        initialAnimationDuration: Duration(milliseconds: 20),
        type: ButtonType.ghost,
        size: ButtonSize.sm,
        leftIcon: WorklogStudioAssets.vectors.playFilled24Svg,
        onTap: () {
          context.read<TimeTrackerBloc>().add(
            TimeTrackerStarted(
              projectId: entry.projectId,
              taskId: entry.taskId,
              comment: entry.comment,
            ),
          );
        },
      );
    }
  }
}
