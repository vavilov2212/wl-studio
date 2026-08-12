import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/tracker_panel_form.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class TrackerCommandPalette extends StatelessWidget {
  final VoidCallback onClose;
  final ValueChanged<String> onOpenProject;
  final ValueChanged<String> onOpenTask;

  const TrackerCommandPalette({
    super.key,
    required this.onClose,
    required this.onOpenProject,
    required this.onOpenTask,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Stack(
      children: [
        ModalBarrier(
          color: const Color.fromRGBO(0, 0, 0, 0.12),
          onDismiss: onClose,
          dismissible: true,
        ),
        Positioned(
          top: screenHeight * 0.18,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: 520,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.background.surface,
                    borderRadius: BorderRadius.circular(theme.radiuses.lg),
                    border: Border.all(color: palette.border.primary),
                    boxShadow: [theme.shadows.md],
                  ),
                  padding: EdgeInsets.all(theme.spacings.xl),
                  child: Focus(
                    autofocus: true,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.escape) {
                        onClose();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TrackerPanelForm(
                      onOpenProject: onOpenProject,
                      onOpenTask: onOpenTask,
                      onDone: onClose,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
