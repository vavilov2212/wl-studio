import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:vector_svg/vector_svg.dart';
import 'select_types.dart';

class SelectTrigger extends StatelessWidget {
  final String? label;
  final String placeholder;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool isOpen;
  final SelectSize size;

  const SelectTrigger({
    super.key,
    required this.label,
    required this.placeholder,
    this.controller,
    this.focusNode,
    this.isOpen = false,
    this.size = SelectSize.md,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final height = switch (size) {
      SelectSize.sm => theme.spacings.x3l,
      SelectSize.md => theme.spacings.x4l,
      SelectSize.lg => theme.spacings.x4l + theme.spacings.sm,
    };
    final verticalPadding = switch (size) {
      SelectSize.sm => theme.spacings.sm,
      SelectSize.md => theme.spacings.md,
      SelectSize.lg => theme.spacings.lg,
    };

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacings.md,
        vertical: verticalPadding,
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
                    style: theme.commonTextStyles.body.copyWith(
                      color: palette.text.primary,
                    ),
                    decoration: InputDecoration(
                      hintText: isOpen ? 'Search...' : (label ?? placeholder),
                      hintStyle: theme.commonTextStyles.body.copyWith(
                        color: label != null && !isOpen
                            ? palette.text.primary
                            : palette.text.muted,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                : Text(
                    label ?? placeholder,
                    style: theme.commonTextStyles.body.copyWith(
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
              width: 18,
              height: 18,
              colorFilter: palette.text.muted.filter,
            ),
          ),
        ],
      ),
    );
  }
}
