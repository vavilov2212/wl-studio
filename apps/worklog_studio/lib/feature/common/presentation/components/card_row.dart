import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class CardColumn {
  final Widget child;
  final int flex;
  final Alignment alignment;

  const CardColumn({
    required this.child,
    this.flex = 1,
    this.alignment = Alignment.centerLeft,
  });
}

class CardRow extends StatelessWidget {
  final List<CardColumn> columns;

  const CardRow({
    super.key,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < columns.length; i++) ...[
          Expanded(
            flex: columns[i].flex,
            child: Align(
              alignment: columns[i].alignment,
              child: columns[i].child,
            ),
          ),
          if (i < columns.length - 1)
            SizedBox(width: theme.spacings.lg),
        ],
      ],
    );
  }
}
