import 'package:flutter/material.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/tracker_chip_bar.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/tracker_quick_pick_panel.dart';

class TrackerSection extends StatefulWidget {
  final ValueChanged<String> onOpenProject;
  final ValueChanged<String> onOpenTask;

  const TrackerSection({
    super.key,
    required this.onOpenProject,
    required this.onOpenTask,
  });

  @override
  State<TrackerSection> createState() => _TrackerSectionState();
}

class _TrackerSectionState extends State<TrackerSection> {
  bool _isPanelOpen = false;

  void _open() {
    if (!_isPanelOpen) setState(() => _isPanelOpen = true);
  }

  void _close() {
    if (_isPanelOpen) setState(() => _isPanelOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: 'tracker-section',
      onTapOutside: (_) => _close(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TrackerChipBar(
            isPanelOpen: _isPanelOpen,
            onOpenPanel: _open,
            onOpenProject: widget.onOpenProject,
            onOpenTask: widget.onOpenTask,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: _isPanelOpen
                ? TrackerQuickPickPanel(
                    onClose: _close,
                    onOpenProject: widget.onOpenProject,
                    onOpenTask: widget.onOpenTask,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
