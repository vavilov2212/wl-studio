import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class TimeEntryActionsCell extends StatelessWidget {
  final ResolvedTimeEntry resolvedEntry;

  const TimeEntryActionsCell({super.key, required this.resolvedEntry});

  @override
  Widget build(BuildContext context) {
    final entry = resolvedEntry.entry;

    final isRunningThis = context.select<TimeTrackerBloc, bool>(
      (bloc) =>
          bloc.state.isRunning && bloc.state.activeEntryOrNull?.id == entry.id,
    );

    if (isRunningThis) {
      return PrimaryButton(
        type: ButtonType.danger,
        size: ButtonSize.sm,
        leftIcon: WorklogStudioAssets.vectors.squareFilled64Svg,
        backgroundColor: context.theme.colorsPalette.accent.danger,
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
