import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class ClearableFilterPill extends StatelessWidget {
  final Widget child;
  final bool isActive;
  final VoidCallback onClear;

  const ClearableFilterPill({
    super.key,
    required this.child,
    required this.isActive,
    required this.onClear,
  });

  /// Space always reserved above and to the right of [child] for the clear
  /// button overlay. Public so sibling rows without a pill can pad
  /// themselves by the same amount and stay aligned with pill-wrapped
  /// controls.
  static const double overlap = 10.0;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    // The widget tree shape returned here must stay IDENTICAL regardless of
    // `isActive` — only the close button's presence should toggle. Returning
    // a bare `child` when inactive and a Stack/Padding-wrapped tree when
    // active would change the widget type at this slot, which makes Flutter
    // discard and recreate the whole subtree on every activation toggle
    // (losing the wrapped control's State, e.g. a MultiSelect's open
    // ComboboxController, and shifting layout since the box size changes
    // only after the rebuild).
    //
    // The close button overlaps the pill's top-right corner. A Stack only
    // hit-tests within its own box even with clipBehavior: Clip.none (which
    // only affects painting), so the box itself must be grown by the overlap
    // amount via padding on the non-positioned child — otherwise the part of
    // the button poking outside the original box is visible but unclickable.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: overlap, right: overlap),
          child: child,
        ),
        if (isActive)
          Positioned(
            top: 0,
            right: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: InkWell(
                onTap: onClear,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: palette.text.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: palette.background.surface,
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 10,
                      color: Colors.white,
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
