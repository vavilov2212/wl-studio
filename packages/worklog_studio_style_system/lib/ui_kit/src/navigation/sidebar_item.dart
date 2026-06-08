import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:vector_svg/vector_svg.dart';

class SidebarItem extends StatefulWidget {
  final String label;
  final String? iconPath;
  final bool isActive;
  final VoidCallback onTap;

  const SidebarItem({
    required this.label,
    required this.onTap,
    this.iconPath,
    this.isActive = false,
    super.key,
  });

  @override
  State<SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<SidebarItem> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final backgroundColor = widget.isActive
        ? palette.background.surface
        : isHovered
        ? palette.background.surfaceMuted.withValues(alpha: 0.5)
        : palette.base.transparent;

    final textColor = widget.isActive
        ? palette.text.primary
        : palette.text.secondary;

    final iconColor = widget.isActive
        ? palette.accent.primary
        : palette.text.muted;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: kThemeAnimationDuration,
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacings.lg,
            vertical: theme.spacings.md,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: theme.radiuses.md.circular,
            border: widget.isActive
                ? Border(
                    left: BorderSide(
                      color: palette.accent.primary,
                      width: 3,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              if (widget.iconPath != null) ...[
                widget.iconPath!.vector(
                  width: 20,
                  height: 20,
                  colorFilter: iconColor.filter,
                ),
                SizedBox(width: theme.spacings.md),
              ],
              Expanded(
                child: Text(
                  widget.label,
                  style: theme.commonTextStyles.bodyBold.copyWith(
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
