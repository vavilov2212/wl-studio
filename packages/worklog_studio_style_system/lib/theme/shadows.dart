import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'package:flutter/cupertino.dart';

class Shadows {
  final ColorsPalette colorsPalette;
  Shadows(this.colorsPalette);

  late final BoxShadow none = BoxShadow(
    color: colorsPalette.base.transparent,
    blurRadius: 0,
  );

  late final BoxShadow sm = BoxShadow(
    offset: Offset(0, 1),
    color: Color(0x08_000000),
    blurRadius: 2,
  );

  late final BoxShadow md = BoxShadow(
    offset: Offset(0, 4),
    color: Color(0x12_000000),
    blurRadius: 12,
  );
}
