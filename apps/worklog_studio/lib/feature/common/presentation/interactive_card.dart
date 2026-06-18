import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class InteractiveCard extends StatefulWidget {
  final Widget child;
  final bool isSelected;
  final VoidCallback? onTap;

  const InteractiveCard({
    super.key,
    required this.child,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;

  void _handleHover(bool isHovered) {
    setState(() => _isHovered = isHovered);
  }

  void _handleFocus(bool isFocused) {
    setState(() => _isFocused = isFocused);
  }

  void _handleHighlight(bool isPressed) {
    setState(() => _isPressed = isPressed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final isDisabled = widget.onTap == null;

    // Centralized state mapping
    Color backgroundColor = palette.background.surface;
    Color borderColor = palette.border.primary;
    List<BoxShadow>? boxShadow;

    if (isDisabled) {
      backgroundColor = palette.background.surfaceMuted.withValues(alpha: 0.5);
      borderColor = palette.border.primary.withValues(alpha: 0.5);
    } else if (widget.isSelected) {
      backgroundColor = palette.background.surface;
      borderColor = palette.accent.primary.withValues(alpha: 0.5);
      boxShadow = [theme.shadows.sm];
    } else if (_isPressed) {
      backgroundColor = palette.background.surfaceMuted;
      borderColor = palette.border.focus;
    } else if (_isHovered || _isFocused) {
      backgroundColor = palette.background.surface;
      borderColor = palette.border.focus;
      boxShadow = [theme.shadows.sm];
    }

    return BaseCard(
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      boxShadow: boxShadow,
      borderRadius: theme.radiuses.lg.circular,
      child: Material(
        color: Colors.transparent,
        borderRadius: theme.radiuses.lg.circular,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHover: _handleHover,
          onFocusChange: _handleFocus,
          onHighlightChanged: _handleHighlight,
          mouseCursor: isDisabled
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: Padding(
            padding: EdgeInsets.all(theme.spacings.lg),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
