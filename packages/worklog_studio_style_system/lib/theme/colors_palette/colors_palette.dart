import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'dart:ui';

const lightColorsPalette = ColorsPalette(
  base: BsColors(transparent: Color(0x00FFFFFF)),
  background: BackgroundColors(
    canvas: Color(0xFFF5F4F1),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEEECEA),
  ),
  border: BorderColors(
    primary: Color(0xFFE2E0DB),
    hover: Color(0xFFC8C5BE),
    focus: Color(0xFF0F172A),
  ),
  text: TextColors(
    primary: Color(0xFF1C1E21),
    secondary: Color(0xFF4B5563),
    secondary2: Color.fromARGB(255, 94, 103, 116),
    muted: Color(0xFF9CA3AF),
  ),
  accent: AccentColors(
    primary: Color(0xFF0F172A),
    primaryMuted: Color(0xFFF0EFF0),
    danger: Color(0xFFDC2626),
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
    nav: Color(0xFF111110),
  ),
);

const darkColorsPalette = ColorsPalette(
  base: BsColors(transparent: Color(0x00FFFFFF)),
  background: BackgroundColors(
    canvas: Color(0xFFF5F4F1),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEEECEA),
  ),
  border: BorderColors(
    primary: Color(0xFFE2E0DB),
    hover: Color(0xFFC8C5BE),
    focus: Color(0xFF0F172A),
  ),
  text: TextColors(
    primary: Color(0xFF1C1E21),
    secondary: Color(0xFF4B5563),
    secondary2: Color.fromARGB(255, 94, 103, 116),
    muted: Color(0xFF9CA3AF),
  ),
  accent: AccentColors(
    primary: Color(0xFF0F172A),
    primaryMuted: Color(0xFFF0EFF0),
    danger: Color(0xFFDC2626),
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
    nav: Color(0xFF111110),
  ),
);
