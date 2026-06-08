import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class AppDrawer extends StatefulWidget {
  final bool isOpen;
  final String? title;
  final Widget? customHeader;
  final Widget body;
  final Widget? footer;
  final VoidCallback? onClose;
  final List<Widget>? actions;
  final double minWidth;
  final double maxWidth;
  final double defaultWidth;

  const AppDrawer({
    super.key,
    required this.isOpen,
    this.title,
    this.customHeader,
    required this.body,
    this.footer,
    this.onClose,
    this.actions,
    this.minWidth = 320.0,
    this.maxWidth = 720.0,
    this.defaultWidth = 420.0,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late double _currentWidth;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentWidth = widget.defaultWidth;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    Widget? headerWidget = widget.customHeader;
    if (headerWidget == null &&
        (widget.title != null ||
            widget.onClose != null ||
            widget.actions != null)) {
      headerWidget = Padding(
        padding: EdgeInsets.fromLTRB(
          theme.spacings.xl,
          theme.spacings.xl,
          theme.spacings.xl,
          theme.spacings.lg,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (widget.onClose != null)
              IconButton(
                icon: Icon(Icons.close, color: palette.text.secondary),
                onPressed: widget.onClose,
              )
            else if (widget.title != null)
              Expanded(
                child: Text(
                  widget.title!,
                  style: theme.commonTextStyles.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              const SizedBox.shrink(),
            if (widget.actions != null)
              Row(mainAxisSize: MainAxisSize.min, children: widget.actions!),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: widget.isOpen ? _currentWidth : 0,
      decoration: BoxDecoration(
        color: palette.background.surface,
        border: Border(
          left: BorderSide(color: palette.border.primary, width: 1),
        ),
      ),
      child: ClipRect(
        child: widget.isOpen
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Resize Handle
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) {
                        setState(() {
                          _isDragging = true;
                        });
                      },
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
                      onPanEnd: (_) {
                        setState(() {
                          _isDragging = false;
                        });
                      },
                      child: Container(
                        width: 8,
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
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (headerWidget != null) headerWidget,
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.only(
                              left: theme.spacings.xl,
                              right: theme.spacings.x2l,
                              top: headerWidget == null
                                  ? theme.spacings.x2l
                                  : 0,
                              bottom: widget.footer == null
                                  ? theme.spacings.x2l
                                  : 0,
                            ),
                            child: widget.body,
                          ),
                        ),
                        if (widget.footer != null)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              theme.spacings.xl,
                              theme.spacings.lg,
                              theme.spacings.x2l,
                              theme.spacings.x2l,
                            ),
                            child: widget.footer!,
                          ),
                      ],
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
