import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class DrawerContent extends StatelessWidget {
  final Widget? meta;
  final Widget content;
  final Widget? footer;

  const DrawerContent({
    super.key,
    this.meta,
    required this.content,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (meta != null) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
              theme.spacings.xl,
              theme.spacings.md,
              theme.spacings.xl,
              theme.spacings.none,
            ),
            child: meta!,
          ),
          SizedBox(height: theme.spacings.x2l),
        ],
        Expanded(child: content),
        if (footer != null) ...[
          Padding(padding: EdgeInsets.all(theme.spacings.xl), child: footer!),
        ],
      ],
    );
  }
}
