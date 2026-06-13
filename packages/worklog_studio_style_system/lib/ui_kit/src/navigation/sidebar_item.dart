import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:vector_svg/vector_svg.dart';

class SidebarItem extends StatefulWidget {
final String label;
final String? iconPath;
final IconData? icon;
final bool isActive;
  final bool collapsed;
final VoidCallback onTap;

const SidebarItem({
required this.label,
required this.onTap,
this.iconPath,
  this.icon,
    this.isActive = false,
  this.collapsed = false,
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
width: 40,
height: 40,
decoration: BoxDecoration(
color: bgColor,
borderRadius: theme.radiuses.md.circular,
),
alignment: Alignment.center,
child: _buildIcon(iconColor, theme, size: 20),
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

final backgroundColor = widget.isActive
? palette.accent.primary
: isHovered
? Colors.white.withValues(alpha: 0.07)
: palette.base.transparent;

final textColor = widget.isActive
? Colors.white
: Colors.white.withValues(alpha: 0.55);

final iconColor = widget.isActive
? Colors.white
: Colors.white.withValues(alpha: 0.45);

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
              ] else if (widget.icon != null) ...[    
                Icon(widget.icon, size: 20, color: iconColor),
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
