import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:vector_svg/vector_svg.dart';

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
          Transform.rotate(
            angle: math.pi / 2,
            child: WorklogStudioAssets.vectors.arrowSmallRight24Svg.vector(
              width: tokens.iconSize,
              height: tokens.iconSize,
              colorFilter: palette.text.muted.filter,
            ),
          ),
        ],
      ),
    );
  }
}
