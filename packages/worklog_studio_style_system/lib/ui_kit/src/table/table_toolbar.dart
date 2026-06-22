import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class TableToolbar extends StatelessWidget {
  final bool isFilterExpanded;
  final VoidCallback onFilterTap;
  final int activeFilterCount;

  const TableToolbar({
    super.key,
    required this.isFilterExpanded,
    required this.onFilterTap,
    this.activeFilterCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Row(
      children: [
        _ToolbarIconButton(
          icon: Icons.filter_list,
          isActive: isFilterExpanded,
          badgeCount: activeFilterCount,
          onTap: onFilterTap,
        ),
        SizedBox(width: theme.spacings.sm),
        const _ToolbarIconButton(icon: Icons.sort, enabled: false),
        SizedBox(width: theme.spacings.sm),
        const _ToolbarIconButton(icon: Icons.settings_outlined, enabled: false),
      ],
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final bool isActive;
  final int badgeCount;
  final VoidCallback? onTap;

  const _ToolbarIconButton({
    required this.icon,
    this.enabled = true,
    this.isActive = false,
    this.badgeCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        PrimaryButton(
          onTap: enabled ? onTap : null,
          isDisabled: !enabled,
          type: isActive ? ButtonType.secondary : ButtonType.ghost,
          size: ButtonSize.sm,
          leftIconWidget: Icon(icon, size: 16),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 14),
              decoration: BoxDecoration(
                color: palette.accent.primary,
                borderRadius: theme.radiuses.pill.circular,
              ),
              child: Text(
                '$badgeCount',
                textAlign: TextAlign.center,
                style: theme.commonTextStyles.caption2.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
