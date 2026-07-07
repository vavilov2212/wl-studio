import 'package:flutter/material.dart';
import 'package:worklog_studio/feature/app/layout/app_route.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class SidebarNavigation extends StatefulWidget {
  final AppRoute currentRoute;
  final ValueChanged<AppRoute> onRouteSelected;

  const SidebarNavigation({
    super.key,
    required this.currentRoute,
    required this.onRouteSelected,
  });

  @override
  State<SidebarNavigation> createState() => _SidebarNavigationState();
}

class _SidebarNavigationState extends State<SidebarNavigation> {
  bool _collapsed = true;
  bool _headerHovered = false;
  bool _settingsExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final navBg = palette.accent.nav;
    final collapsedWidth = 56.0;
    final expandedWidth = 220.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _collapsed ? collapsedWidth : expandedWidth,
      decoration: BoxDecoration(
        color: navBg,
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          // Brand + toggle — the whole row is clickable to expand/collapse.
          Tooltip(
            message: _collapsed ? 'Expand sidebar' : 'Collapse sidebar',
            preferBelow: true,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _headerHovered = true),
              onExit: (_) => setState(() => _headerHovered = false),
              child: GestureDetector(
                onTap: () => setState(() => _collapsed = !_collapsed),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 56,
                  color: _headerHovered
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.transparent,
                  padding: EdgeInsets.symmetric(horizontal: theme.spacings.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        margin: EdgeInsets.only(
                          left: _collapsed ? 4 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: theme.radiuses.sm.circular,
                        ),
                        child: Icon(
                          Icons.access_time_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      if (!_collapsed) ...[
                        SizedBox(width: theme.spacings.sm),
                        Expanded(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _collapsed ? 0 : 1,
                            child: Text(
                              'Worklog Studio',
                              style: theme.commonTextStyles.labelMedium
                                  .copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Nav items
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _collapsed ? 8 : theme.spacings.sm,
                vertical: theme.spacings.sm,
              ),
              child: Column(
                spacing: theme.spacings.xxs,
                children: [
                  _navItem(AppRoute.dashboard, 'Dashboard', Icons.grid_view_rounded),
                  _navItem(AppRoute.history, 'History', Icons.history_rounded),
                  if (!_collapsed)
                    Padding(
                      padding: EdgeInsets.only(
                        top: theme.spacings.md,
                        bottom: theme.spacings.xxs,
                        left: theme.spacings.lg,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Manage',
                          style: theme.commonTextStyles.labelSmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.25),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(height: theme.spacings.sm),
                  _navItem(AppRoute.projects, 'Projects', Icons.folder_outlined),
                  _navItem(AppRoute.tasks, 'Tasks', Icons.check_box_outlined),
                  if (!_collapsed)
                    Padding(
                      padding: EdgeInsets.only(
                        top: theme.spacings.md,
                        bottom: theme.spacings.xxs,
                        left: theme.spacings.lg,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'General',
                          style: theme.commonTextStyles.labelSmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.25),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(height: theme.spacings.sm),
                  ..._settingsNavGroup(),
                ],
              ),
            ),
          ),
          // Footer
          Container(
            height: 56,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: _collapsed ? 8 : 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  margin: EdgeInsets.only(left: _collapsed ? 4 : 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'WS',
                    style: theme.commonTextStyles.caption3Bold.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 9,
                    ),
                  ),
                ),
                if (!_collapsed) ...[
                  SizedBox(width: theme.spacings.sm),
                  Expanded(
                    child: Text(
                      'Worklog Studio',
                      style: theme.commonTextStyles.labelSmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(AppRoute route, String label, IconData icon) {
    return SidebarItem(
      label: label,
      icon: icon,
      isActive: widget.currentRoute == route,
      collapsed: _collapsed,
      onTap: () => widget.onRouteSelected(route),
    );
  }

  /// The expandable "Settings" entry plus its "General"/"Hotkeys" children.
  ///
  /// When the sidebar itself is collapsed (icon-only mode) there's no room
  /// to show children inline, so tapping the parent navigates straight to
  /// the active settings sub-route (or General by default) instead of
  /// toggling an expansion that wouldn't be visible anyway.
  List<Widget> _settingsNavGroup() {
    final isOnSettings = isSettingsRoute(widget.currentRoute);

    final parent = SidebarItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      isActive: isOnSettings && (_collapsed || !_settingsExpanded),
      collapsed: _collapsed,
      trailing: _collapsed
          ? null
          : Icon(
              _settingsExpanded
                  ? Icons.expand_more_rounded
                  : Icons.chevron_right_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.45),
            ),
      onTap: () {
        if (_collapsed) {
          // No room to show General/Hotkeys inline while collapsed - expand
          // the whole sidebar so they become reachable, rather than
          // guessing which one the user wants.
          setState(() {
            _collapsed = false;
            _settingsExpanded = true;
          });
        } else {
          setState(() => _settingsExpanded = !_settingsExpanded);
        }
        if (!isSettingsRoute(widget.currentRoute)) {
          widget.onRouteSelected(AppRoute.settingsGeneral);
        }
      },
    );

    if (_collapsed || !_settingsExpanded) {
      return [parent];
    }

    return [
      parent,
      _subNavItem(AppRoute.settingsGeneral, 'General'),
      _subNavItem(AppRoute.settingsHotkeys, 'Hotkeys'),
    ];
  }

  /// A nested item under the expandable "Settings" entry. Reuses
  /// [SidebarItem] itself (rather than a bespoke widget) so sub-items get
  /// the exact same hover/active/full-width row behavior as top-level
  /// items - `dense: true` gives them the lighter visual weight expected
  /// of a subordinate entry, and `indent` nests them under their parent.
  Widget _subNavItem(AppRoute route, String label) {
    final theme = context.theme;
    return SidebarItem(
      label: label,
      isActive: widget.currentRoute == route,
      indent: theme.spacings.xl,
      variant: SidebarItemVariant.nested,
      onTap: () => widget.onRouteSelected(route),
    );
  }
}
