import 'package:flutter/material.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/global_time_tracker_panel.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class TopAppBar extends StatelessWidget {
  final ValueChanged<String> onOpenProject;
  final ValueChanged<String> onOpenTask;

  const TopAppBar({
    super.key,
    required this.onOpenProject,
    required this.onOpenTask,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.background.surface,
        border: Border(bottom: BorderSide(color: palette.border.primary)),
      ),
      child: GlobalTimeTrackerPanel(
        onOpenProject: onOpenProject,
        onOpenTask: onOpenTask,
      ),
    );
  }
}
