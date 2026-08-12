import 'package:flutter/material.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/tracker_section.dart';

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
    return TrackerSection(
      onOpenProject: onOpenProject,
      onOpenTask: onOpenTask,
    );
  }
}
