import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'dart:ui';

const lightColorsPalette = ColorsPalette(
  base: BsColors(transparent: Color(0x00FFFFFF)),
  background: BackgroundColors(
    canvas: Color(0xFFF8F9FB),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F4F7),
  ),
  border: BorderColors(
    primary: Color(0xFFD1D5DB),
    hover: Color(0xFF9CA3AF),
    focus: Color(0xFF3B82F6),
  ),
  text: TextColors(
    primary: Color(0xFF1C1E21),
    secondary: Color(0xFF4B5563),
    secondary2: Color.fromARGB(255, 94, 103, 116),
    muted: Color(0xFF9CA3AF),
  ),
  accent: AccentColors(
    primary: Color(0xFF0053DB),
    primaryMuted: Color(0xFFE5EDFB),
    danger: Color(0xFFDC2626),
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
  ),
);

const darkColorsPalette = ColorsPalette(
  base: BsColors(transparent: Color(0x00FFFFFF)),
  background: BackgroundColors(
    canvas: Color(0xFFF8F9FB),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F4F7),
  ),
  border: BorderColors(
    primary: Color(0xFFD1D5DB),
    hover: Color(0xFF9CA3AF),
    focus: Color(0xFF3B82F6),
  ),
  text: TextColors(
    primary: Color(0xFF1C1E21),
    secondary: Color(0xFF4B5563),
    secondary2: Color.fromARGB(255, 94, 103, 116),
    muted: Color(0xFF9CA3AF),
  ),
  accent: AccentColors(
    primary: Color(0xFF0053DB),
    primaryMuted: Color(0xFFE5EDFB),
    danger: Color(0xFFDC2626),
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
  ),
);
