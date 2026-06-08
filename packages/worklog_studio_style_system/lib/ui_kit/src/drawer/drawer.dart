import 'package:flutter/material.dart' hide DrawerController;
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

/*
 * Author: Roman Vavilov
 * Date: 26.01.2026 16:54 UTC:-05:00
 *
 * TODO: Make drawer to show at the top of the stacking context
 */

class Drawer extends StatefulWidget {
  final Widget child;

  final DrawerController controller;
  /*
   * Fraction of the width of the screen
   * for initial render of widget
   * e.g. screenWidth * _widthFactor
   */
  final double? widthFactor;

  /*
   * From where the sheet is shown
   */
  final AlignmentGeometry? alignment;

  const Drawer({
    required this.child,
    required this.controller,
    this.widthFactor = 0.8,
    this.alignment = Alignment.centerRight,
    super.key,
  });

  @override
  State<Drawer> createState() => _DrawerState();
}

class _DrawerState extends State<Drawer> {
  late double _widthFactor;
  late bool _isOpen;

  @override
  void initState() {
    _widthFactor = widget.widthFactor!;
    _isOpen = widget.controller.isOpen;
    widget.controller.addListener(_onControllerChanged);
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (_isOpen == widget.controller.isOpen) return;

    setState(() {
      _isOpen = widget.controller.isOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOpen) return SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;

    return Align(
      alignment: widget.alignment!,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.theme.colorsPalette.background.surface,
          border: Border.all(color: context.theme.colorsPalette.border.primary),
          /*
           * Author: Roman Vavilov
           * Date: 26.01.2026 16:06 UTC:-05:00
           *
           * TODO: Think of the rounded corners
           * 
           * borderRadius: BorderRadius.only(
           *   topLeft: Radius.circular(context.theme.radiuses.lg),
           *   bottomLeft: Radius.circular(context.theme.radiuses.lg),
           * ),
           */
        ),
        child: SizedBox(
          width: screenWidth * _widthFactor,

          child: Row(
            children: [
              _ResizeHandle(
                width: context.theme.spacings.xl,
                onHorizontalDrag: (dx) {
                  setState(() {
                    _widthFactor -= dx / screenWidth;
                    _widthFactor = _widthFactor.clamp(0.0, 1.0);
                  });
                },
              ),
              Expanded(
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 100),
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  final double width;
  final ValueChanged<double> onHorizontalDrag;

  const _ResizeHandle({required this.width, required this.onHorizontalDrag});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          onHorizontalDrag(details.delta.dx);
        },
        child: SizedBox(
          width: width,
          child: Center(
            /*
             * Author: Roman Vavilov
             * Date: 26.01.2026 16:10 UTC:-05:00
             *
             * TODO: Style the drag nob
             */
            child: Container(
              width: 2,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
