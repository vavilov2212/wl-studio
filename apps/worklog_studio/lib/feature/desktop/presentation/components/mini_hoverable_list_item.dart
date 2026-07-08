import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class MiniHoverableListItem extends StatefulWidget {
  final Widget? leading;
  final Widget Function(bool isHovered)? leadingWidget;
  final String title;
  final String? subtitle;
  final Widget Function(bool isHovered)? trailingWidget;
  final Widget? trailing;
  final VoidCallback onTap;

  const MiniHoverableListItem({
    super.key,
    this.leading,
    this.leadingWidget,
    required this.title,
    this.subtitle,
    this.trailingWidget,
    this.trailing,
    required this.onTap,
  });

  @override
  State<MiniHoverableListItem> createState() => _MiniHoverableListItemState();
}

class _MiniHoverableListItemState extends State<MiniHoverableListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: theme.spacings.sm,
            horizontal: theme.spacings.md,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? theme.colorsPalette.accent.primaryMuted
                : Colors.transparent,
            borderRadius: BorderRadius.circular(theme.radiuses.sm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              widget.leading ?? const SizedBox.shrink(),
              widget.leadingWidget?.call(_isHovered) ?? const SizedBox.shrink(),
              (widget.leading == null && widget.leadingWidget == null)
                  ? const SizedBox.shrink()
                  : SizedBox(width: theme.spacings.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.commonTextStyles.body.copyWith(
                        color: theme.colorsPalette.text.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subtitle != null) ...[
                      SizedBox(height: theme.spacings.xs),
                      Text(
                        widget.subtitle!,
                        style: theme.commonTextStyles.caption.copyWith(
                          color: theme.colorsPalette.text.secondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: theme.spacings.sm),
              widget.trailing ?? const SizedBox.shrink(),
              widget.trailingWidget?.call(_isHovered) ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
