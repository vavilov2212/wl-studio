import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class DrawerHeader extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onDelete;
  final List<Widget>? extraActions;

  const DrawerHeader({
    super.key,
    required this.onClose,
    this.onDelete,
    this.extraActions,
  });

  @override
  State<DrawerHeader> createState() => _DrawerHeaderState();
}

class _DrawerHeaderState extends State<DrawerHeader> {
  final PopoverController _popoverController = PopoverController();

  @override
  void dispose() {
    _popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacings.xl,
        theme.spacings.xl,
        theme.spacings.xl,
        theme.spacings.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.close, color: palette.text.secondary, size: 18),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: widget.onClose,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.extraActions != null) ...widget.extraActions!,
              PopoverPrimitive(
                controller: _popoverController,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                width: 180,
                trigger: IconButton(
                  icon: Icon(
                    Icons.more_horiz,
                    color: palette.text.secondary,
                    size: 18,
                  ),
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: _popoverController.toggle,
                ),
                contentBuilder: (context) {
                  return PopoverSurface(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: theme.spacings.sm,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PopoverAction(
                            icon: Icons.delete_outline,
                            label: 'Delete',
                            color: palette.accent.danger,
                            onTap: () {
                              _popoverController.hide();
                              widget.onDelete?.call();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PopoverAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PopoverAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacings.lg,
          vertical: theme.spacings.md,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: theme.spacings.md),
            Text(
              label,
              style: theme.commonTextStyles.body.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
