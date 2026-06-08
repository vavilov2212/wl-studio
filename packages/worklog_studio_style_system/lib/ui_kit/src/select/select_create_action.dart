import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class SelectCreateAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const SelectCreateAction({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacings.md,
          vertical: theme.spacings.md,
        ),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border.primary)),
        ),
        child: Row(
          children: [
            Icon(Icons.add, size: 16, color: palette.accent.primary),
            SizedBox(width: theme.spacings.sm),
            Expanded(
              child: Text(
                label,
                style: theme.commonTextStyles.body.copyWith(
                  color: palette.accent.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
