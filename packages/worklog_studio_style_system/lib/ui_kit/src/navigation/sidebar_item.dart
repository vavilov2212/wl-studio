import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:vector_svg/vector_svg.dart';

/// Visual weight of a [SidebarItem].
enum SidebarItemVariant {
  /// A top-level destination - bold label, solid active highlight.
  standard,

  /// A nested entry under a parent (e.g. "Settings > General") - regular
  /// label weight and a softer active highlight, so it reads as
  /// subordinate rather than a second row of equally-weighted items.
  nested,
}

class SidebarItem extends StatefulWidget {
final String label;
final String? iconPath;
final IconData? icon;
final bool isActive;
  final bool collapsed;
final VoidCallback onTap;
  /// Optional trailing widget (e.g. an expand/collapse chevron), rendered
  /// only in expanded (non-collapsed) mode.
  final Widget? trailing;
  /// Extra leading space before the icon/label, for rendering a nested
  /// sub-item under a parent (e.g. "Settings > General"). Ignored in
  /// [collapsed] mode, where there is no room for a visible hierarchy.
  final double indent;
  final SidebarItemVariant variant;

const SidebarItem({
required this.label,
required this.onTap,
this.iconPath,
  this.icon,
    this.isActive = false,
  this.collapsed = false,
  this.trailing,
  this.indent = 0,
  this.variant = SidebarItemVariant.standard,
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

if (widget.collapsed) {
      return _buildCollapsed(context, theme, palette);
}
return _buildExpanded(context, theme, palette);
}

Widget _buildCollapsed(
BuildContext context,
AppThemeExtension theme,
    colorsPalette,
) {
final palette = theme.colorsPalette;
final isNavDark = true; // collapsed sidebar is always on dark nav bg

final iconColor = widget.isActive
? Colors.white
: isHovered
? Colors.white.withValues(alpha: 0.75)
: Colors.white.withValues(alpha: 0.38);

final bgColor = widget.isActive
? Colors.white.withValues(alpha: 0.12)
: isHovered
? Colors.white.withValues(alpha: 0.07)
: Colors.transparent;

return MouseRegion(
onEnter: (_) => setState(() => isHovered = true),
onExit: (_) => setState(() => isHovered = false),
cursor: SystemMouseCursors.click,
child: Tooltip(
message: widget.label,
preferBelow: false,
child: GestureDetector(
onTap: widget.onTap,
child: AnimatedContainer(
duration: kThemeAnimationDuration,
width: 36,
height: 36,
decoration: BoxDecoration(
color: bgColor,
borderRadius: theme.radiuses.md.circular,
),
alignment: Alignment.center,
child: _buildIcon(iconColor, theme, size: 18),
),
),
),
);
}

Widget _buildExpanded(
BuildContext context,
AppThemeExtension theme,
colorsPalette,
) {
final palette = theme.colorsPalette;

final isNested = widget.variant == SidebarItemVariant.nested;

final backgroundColor = widget.isActive
? (isNested ? Colors.white.withValues(alpha: 0.12) : palette.accent.primary)
: isHovered
? Colors.white.withValues(alpha: 0.07)
: palette.base.transparent;

final textColor = widget.isActive
? Colors.white
: Colors.white.withValues(alpha: isNested ? 0.65 : 0.55);

final iconColor = widget.isActive
? Colors.white
: Colors.white.withValues(alpha: 0.45);

final textStyle = isNested
? theme.commonTextStyles.body2
: theme.commonTextStyles.body2Bold;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: kThemeAnimationDuration,
          padding: EdgeInsets.only(
            left: theme.spacings.md + widget.indent,
            right: theme.spacings.md,
            top: isNested ? theme.spacings.xs : theme.spacings.sm,
            bottom: isNested ? theme.spacings.xs : theme.spacings.sm,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: theme.radiuses.md.circular,
          ),
          child: Row(
            children: [
              if (widget.iconPath != null) ...[
                widget.iconPath!.vector(
                  width: 18,
                  height: 18,
                  colorFilter: iconColor.filter,
                ),
                SizedBox(width: theme.spacings.sm),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: iconColor),
                SizedBox(width: theme.spacings.sm),
              ],
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: textStyle.copyWith(color: textColor),
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(Color color, AppThemeExtension theme, {double size = 20}) {
    if (widget.iconPath != null) {
      return widget.iconPath!.vector(
        width: size,
        height: size,
        colorFilter: color.filter,
      );
    } else if (widget.icon != null) {
      return Icon(widget.icon, size: size, color: color);
    }
    return SizedBox(width: size, height: size);
  }
}
