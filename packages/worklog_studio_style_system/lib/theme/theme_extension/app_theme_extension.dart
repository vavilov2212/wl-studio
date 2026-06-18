import 'package:worklog_studio_style_system/theme/app_theme.dart';
import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette.dart';
import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'package:worklog_studio_style_system/theme/control_size.dart';
import 'package:worklog_studio_style_system/theme/gradients/gradients.dart';
import 'package:worklog_studio_style_system/theme/radiuses.dart';
import 'package:worklog_studio_style_system/theme/shadows.dart';
import 'package:worklog_studio_style_system/theme/spacings.dart';
import 'package:worklog_studio_style_system/theme/text_styles/common_text_styles.dart';
import 'package:flutter/material.dart';

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final ColorsPalette colorsPalette;
  final CommonTextStyles commonTextStyles;
  final Spacings spacings;
  final Radiuses radiuses;
  final Gradients gradients;
  final Shadows shadows;

  AppThemeExtension({required this.colorsPalette})
    : commonTextStyles = CommonTextStyles(),
      spacings = Spacings(),
      radiuses = Radiuses(),
      gradients = Gradients(),
      shadows = Shadows(colorsPalette);

  factory AppThemeExtension.light() =>
      AppThemeExtension(colorsPalette: lightColorsPalette);

  factory AppThemeExtension.dark() =>
      AppThemeExtension(colorsPalette: darkColorsPalette);

  ControlSizeTokens controlSize(ControlSize size) => switch (size) {
    ControlSize.sm => ControlSizeTokens(
      height: spacings.x3l,
      verticalPadding: 0,
      horizontalPadding: spacings.md,
      allPadding: EdgeInsets.symmetric(
        horizontal: spacings.md,
        vertical: spacings.sm,
      ),
      textStyle: commonTextStyles.body2,
      iconSize: 16,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    ),
    ControlSize.md => ControlSizeTokens(
      height: spacings.x4l,
      verticalPadding: spacings.md,
      horizontalPadding: spacings.md,
      allPadding: EdgeInsets.all(spacings.lg),
      textStyle: commonTextStyles.body,
      iconSize: 20,
      isDense: false,
    ),
    ControlSize.lg => ControlSizeTokens(
      height: spacings.x4l + spacings.sm,
      verticalPadding: spacings.lg,
      horizontalPadding: spacings.lg,
      allPadding: EdgeInsets.all(spacings.xl),
      textStyle: commonTextStyles.body,
      iconSize: 20,
      isDense: false,
    ),
  };

  @override
  ThemeExtension<AppThemeExtension> copyWith({ColorsPalette? colorsPalette}) =>
      AppThemeExtension(colorsPalette: colorsPalette ?? this.colorsPalette);

  @override
  ThemeExtension<AppThemeExtension> lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) => AppThemeExtension(colorsPalette: colorsPalette);
}

extension BuildContextExtension on BuildContext {
  AppThemeExtension get theme => AppTheme.themeExtension(this);
}
