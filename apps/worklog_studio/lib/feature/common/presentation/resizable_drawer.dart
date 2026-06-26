import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

enum DrawerMode { push, overlay }

class ResizableDrawer extends StatefulWidget {
  final bool isOpen;
  final Widget? header;
  final Widget body;
  final Widget? footer;
  final VoidCallback? onClose;

  final DrawerMode mode;
  final bool showBackdrop;
  final VoidCallback? onBackdropTap;

  final double minWidth;
  final double maxWidth;
  final double defaultWidth;
  final Color? backgroundColor;

  const ResizableDrawer({
    super.key,
    required this.isOpen,
    this.header,
    required this.body,
    this.footer,
    this.onClose,
    this.mode = DrawerMode.push,
    this.showBackdrop = true,
    this.onBackdropTap,
    this.minWidth = 320.0,
    this.maxWidth = 920.0,
    this.defaultWidth = 620.0,
    this.backgroundColor,
  });

  @override
  State<ResizableDrawer> createState() => _ResizableDrawerState();
}

class _ResizableDrawerState extends State<ResizableDrawer> {
  late double _currentWidth;
  bool _isDragging = false;
  bool _isClosed = true;

  @override
  void initState() {
    super.initState();
    _currentWidth = widget.defaultWidth;
    _isClosed = !widget.isOpen;
  }

  @override
  void didUpdateWidget(ResizableDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultWidth != widget.defaultWidth) {
      _currentWidth = widget.defaultWidth;
    }
    if (widget.isOpen) {
      _isClosed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    if (_isClosed && !widget.isOpen) {
      return const SizedBox.shrink();
    }

    final drawerContent = AnimatedContainer(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: widget.isOpen ? _currentWidth : 0,
      onEnd: () {
        if (!widget.isOpen && mounted) {
          setState(() => _isClosed = true);
        }
      },
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? palette.background.surface,
        border: Border(
          left: BorderSide(color: palette.border.primary, width: 1),
        ),
      ),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Content (offset right of the resize handle)
            Positioned(
              top: 0,
              bottom: 0,
              left: 16,
              right: 0,
              child: BaseDrawer(
                header: widget.header,
                body: widget.body,
                footer: widget.footer,
              ),
            ),
            // Resize Handle (absolutely positioned, never affects Row layout)
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: 16,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (_) => setState(() => _isDragging = true),
                  onPanUpdate: (details) {
                    setState(() {
                      _currentWidth -= details.delta.dx;
                      if (_currentWidth < widget.minWidth) {
                        _currentWidth = widget.minWidth;
                      } else if (_currentWidth > widget.maxWidth) {
                        _currentWidth = widget.maxWidth;
                      }
                    });
                  },
                  onPanEnd: (_) => setState(() => _isDragging = false),
                  child: Container(
                    color: Colors.transparent,
                    alignment: Alignment.center,
                    child: Container(
                      width: 2,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _isDragging
                            ? palette.accent.primary
                            : palette.border.primary,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.mode == DrawerMode.push) {
      return drawerContent;
    }

    // Overlay Mode
    return Stack(
      children: [
        // Backdrop
        if (widget.showBackdrop)
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onBackdropTap ?? widget.onClose,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: widget.isOpen ? 1.0 : 0.0,
                child: Container(color: Colors.black.withValues(alpha: 0.3)),
              ),
            ),
          ),
        // Drawer
        Positioned(top: 0, bottom: 0, right: 0, child: drawerContent),
      ],
    );
  }
}
