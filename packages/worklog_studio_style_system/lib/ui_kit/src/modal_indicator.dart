import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class ModalIndicator extends StatelessWidget {
  const ModalIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: context.theme.spacings.sm),
      width: 32,
      height: 4,
      decoration: BoxDecoration(
        color: context.theme.colorsPalette.border.primary,
        borderRadius: context.theme.radiuses.sm.circular,
      ),
    );
  }
}
