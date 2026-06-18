import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class TextLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final TextStyle? style;
  final Color? color;
  final int? maxLines;
  final Duration initialAnimationDuration;

  const TextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.style,
    this.color,
    this.maxLines = 1,
    this.initialAnimationDuration = const Duration(milliseconds: 20),
  });

  @override
  State<TextLink> createState() => _TextLinkState();
}

class _TextLinkState extends State<TextLink> {
  bool isHovered = false;

  Color _darken(Color color, [double amount = 0.15]) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final baseColor = widget.color ?? palette.accent.primary;
    final hoverColor = _darken(baseColor);
    final baseStyle = widget.style ?? theme.commonTextStyles.bodyBold;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: widget.initialAnimationDuration,
          style: baseStyle.copyWith(
            color: isHovered ? hoverColor : baseColor,
          ),
          child: Text(
            widget.label,
            maxLines: widget.maxLines,
            overflow: TextOverflow.ellipsis,
            softWrap: widget.maxLines == null,
          ),
        ),
      ),
    );
  }
}
