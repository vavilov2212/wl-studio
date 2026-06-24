import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class SelectTrigger extends StatelessWidget {
  final String? label;
  final String placeholder;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool isOpen;
  final ControlSize size;

  const SelectTrigger({
    super.key,
    required this.label,
    required this.placeholder,
    this.controller,
    this.focusNode,
    this.isOpen = false,
    this.size = ControlSize.sm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final tokens = theme.controlSize(size);

    return Container(
      height: tokens.height,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.horizontalPadding,
        vertical: tokens.verticalPadding,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: isOpen ? palette.accent.primary : palette.border.primary,
        ),
        borderRadius: theme.radiuses.md.circular,
        color: palette.background.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: controller != null
                ? TextField(
                    controller: controller,
                    focusNode: focusNode,
                    mouseCursor: isOpen
                        ? SystemMouseCursors.text
                        : SystemMouseCursors.click,
                    style: tokens.textStyle.copyWith(color: palette.text.primary),
                    decoration: InputDecoration(
                      hintText: isOpen ? 'Search...' : (label ?? placeholder),
                      hintStyle: tokens.textStyle.copyWith(
                        color: label != null && !isOpen
                            ? palette.text.primary
                            : palette.text.muted,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: tokens.isDense,
                      contentPadding: tokens.contentPadding,
                    ),
                  )
                : Text(
                    label ?? placeholder,
                    style: tokens.textStyle.copyWith(
                      color: label != null
                          ? palette.text.primary
                          : palette.text.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          _TriggerChevron(
            isOpen: isOpen,
            size: tokens.iconSize,
            color: palette.text.muted,
            hoverColor: palette.text.primary,
          ),
        ],
      ),
    );
  }
}

/// Trigger chevron: points down when closed, flips to point up when open,
/// and darkens on hover.
class _TriggerChevron extends StatefulWidget {
  final bool isOpen;
  final double size;
  final Color color;
  final Color hoverColor;

  const _TriggerChevron({
    required this.isOpen,
    required this.size,
    required this.color,
    required this.hoverColor,
  });

  @override
  State<_TriggerChevron> createState() => _TriggerChevronState();
}

class _TriggerChevronState extends State<_TriggerChevron> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: Icon(
          widget.isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          key: ValueKey(widget.isOpen),
          size: widget.size,
          color: _isHovered ? widget.hoverColor : widget.color,
        ),
      ),
    );
  }
}
