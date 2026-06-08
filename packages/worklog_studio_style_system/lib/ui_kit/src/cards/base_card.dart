import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class BaseCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;

  const BaseCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.boxShadow,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    return Container(
      padding: padding ?? EdgeInsets.all(theme.spacings.s16),
      decoration: BoxDecoration(
        color: backgroundColor ?? palette.background.surface,
        border: Border.all(
          color: borderColor ?? palette.border.primary.withValues(alpha: 0.4),
        ),
        borderRadius: borderRadius ?? theme.radiuses.md.circular,
        boxShadow: boxShadow ?? [theme.shadows.sm],
      ),
      child: child,
    );
  }
}
