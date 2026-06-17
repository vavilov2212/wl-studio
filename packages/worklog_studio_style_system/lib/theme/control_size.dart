import 'package:flutter/material.dart';

enum ControlSize { sm, md, lg }

class ControlSizeTokens {
  final double height;
  final double verticalPadding;
  final double horizontalPadding;
  final EdgeInsets allPadding;
  final TextStyle textStyle;
  final double iconSize;
  final bool isDense;
  final EdgeInsets? contentPadding;

  ControlSizeTokens({
    required this.height,
    required this.verticalPadding,
    required this.horizontalPadding,
    required this.allPadding,
    required this.textStyle,
    required this.iconSize,
    required this.isDense,
    this.contentPadding,
  });
}
