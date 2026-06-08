import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class AppCard extends StatefulWidget {
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? accentColor;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;

  const AppCard({
    super.key,
    this.isSelected = false,
    this.onTap,
    this.accentColor,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final bool isDisabled = widget.onTap == null;

    // Determine background color based on state
    Color backgroundColor = palette.background.surface;
    if (isDisabled) {
      backgroundColor = palette.background.surfaceMuted.withValues(alpha: 0.5);
    } else if (_isPressed) {
      backgroundColor = palette.background.surfaceMuted;
    } else if (_isHovered) {
      backgroundColor = palette.background.surface;
    }

    // Determine border color based on state
    Color borderColor = palette.border.primary;
    if (widget.isSelected) {
      borderColor = palette.accent.primary.withValues(alpha: 0.5);
    } else if (_isHovered && !isDisabled) {
      borderColor = palette.border.focus;
    }

    return MouseRegion(
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(theme.spacings.lg),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: theme.radiuses.lg.circular,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: widget.isSelected
                ? [theme.shadows.sm]
                : (_isHovered && !isDisabled ? [theme.shadows.sm] : []),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Accent
              if (widget.accentColor != null)
                Container(
                  width: 4,
                  height: 40,
                  margin: EdgeInsets.only(right: theme.spacings.lg),
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    borderRadius: theme.radiuses.pill.circular,
                  ),
                )
              else
                SizedBox(width: theme.spacings.lg + 4),

              // Main Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    widget.title,
                    if (widget.subtitle != null) ...[
                      SizedBox(height: theme.spacings.xxs),
                      widget.subtitle!,
                    ],
                  ],
                ),
              ),

              // Right Meta
              if (widget.trailing != null) ...[
                SizedBox(width: theme.spacings.lg),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
