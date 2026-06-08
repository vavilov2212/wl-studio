import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class MasterListCard extends StatelessWidget {
  final String title;
  final String? metadata;
  final Widget? trailing;
  final Color? accentColor;
  final VoidCallback? onTap;

  const MasterListCard({
    required this.title,
    this.metadata,
    this.trailing,
    this.accentColor,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return InkWell(
      onTap: onTap,
      borderRadius: theme.radiuses.md.circular,
      child: Container(
        decoration: BoxDecoration(
          color: palette.background.surface,
          borderRadius: theme.radiuses.md.circular,
          border: accentColor != null
              ? Border(
                  left: BorderSide(
                    color: accentColor!,
                    width: theme.spacings.s4,
                  ),
                )
              : null,
        ),
        padding: EdgeInsets.all(theme.spacings.s16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.commonTextStyles.body2Bold.copyWith(
                      color: palette.text.primary,
                    ),
                  ),
                  if (metadata != null) ...[
                    SizedBox(height: theme.spacings.s4),
                    Text(
                      metadata!,
                      style: theme.commonTextStyles.body2.copyWith(
                        color: palette.text.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              SizedBox(width: theme.spacings.s16),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
