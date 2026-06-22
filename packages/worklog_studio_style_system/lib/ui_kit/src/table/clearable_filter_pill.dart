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

  @override
  Widget build(BuildContext context) {
    if (!isActive) return child;

    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onClear,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: palette.text.secondary,
                shape: BoxShape.circle,
                border: Border.all(color: palette.background.surface, width: 1.5),
              ),
              child: const Icon(Icons.close, size: 10, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
