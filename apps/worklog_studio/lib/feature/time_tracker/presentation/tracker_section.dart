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
  final _chipKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isPanelOpen = false;

  void _open() {
    if (_overlayEntry != null) return;

    final chipBox =
        _chipKey.currentContext?.findRenderObject() as RenderBox?;
    if (chipBox == null) return;

    final topLeft = chipBox.localToGlobal(Offset.zero);
    final panelTop = topLeft.dy + chipBox.size.height;
    final panelLeft = topLeft.dx;
    final panelWidth = chipBox.size.width;

    _overlayEntry = OverlayEntry(
      builder: (_) => _OverlayContent(
        panelTop: panelTop,
        panelLeft: panelLeft,
        panelWidth: panelWidth,
        onClose: _close,
        onOpenProject: widget.onOpenProject,
        onOpenTask: widget.onOpenTask,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isPanelOpen = true);
  }

  void _close() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
    if (mounted) setState(() => _isPanelOpen = false);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _chipKey,
      child: TrackerChipBar(
        isPanelOpen: _isPanelOpen,
        onOpenPanel: _open,
        onOpenProject: widget.onOpenProject,
        onOpenTask: widget.onOpenTask,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overlay content - separate StatefulWidget so it owns the entrance animation
// ---------------------------------------------------------------------------

class _OverlayContent extends StatefulWidget {
  final double panelTop;
  final double panelLeft;
  final double panelWidth;
  final VoidCallback onClose;
  final ValueChanged<String> onOpenProject;
  final ValueChanged<String> onOpenTask;

  const _OverlayContent({
    required this.panelTop,
    required this.panelLeft,
    required this.panelWidth,
    required this.onClose,
    required this.onOpenProject,
    required this.onOpenTask,
  });

  @override
  State<_OverlayContent> createState() => _OverlayContentState();
}

class _OverlayContentState extends State<_OverlayContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.04),
      end: Offset.zero,
    ).animate(_fade);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop - tapping outside closes the panel
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onClose,
            child: const ColoredBox(color: Color.fromRGBO(0, 0, 0, 0.10)),
          ),
        ),

        // Panel anchored below the chip bar
        Positioned(
          top: widget.panelTop,
          left: widget.panelLeft,
          width: widget.panelWidth,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Center(
                child: ConstrainedBox(
                  // max width gives the VS Code "command palette" look on wide screens
                  constraints: BoxConstraints(
                    maxWidth: widget.panelWidth.clamp(0, 680),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: TrackerQuickPickPanel(
                      onClose: widget.onClose,
                      onOpenProject: widget.onOpenProject,
                      onOpenTask: widget.onOpenTask,
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
