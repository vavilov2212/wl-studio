import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class SelectCreateAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final ControlSize size;

  const SelectCreateAction({
    super.key,
    required this.label,
    required this.onTap,
    this.size = ControlSize.sm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final tokens = theme.controlSize(size);

    final itemPadding = tokens.verticalPadding == 0
        ? theme.spacings.sm
        : tokens.verticalPadding;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.horizontalPadding,
          vertical: itemPadding,
        ),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border.primary)),
        ),
        child: Row(
          children: [
            Icon(Icons.add, size: tokens.iconSize, color: palette.accent.primary),
            SizedBox(width: theme.spacings.sm),
            Expanded(
              child: Text(
                label,
                style: tokens.textStyle.copyWith(color: palette.accent.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
