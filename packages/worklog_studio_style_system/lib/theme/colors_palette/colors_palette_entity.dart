import 'dart:ui';

class ColorsPalette {
  final BsColors base;
  final BackgroundColors background;
  final BorderColors border;
  final TextColors text;
  final AccentColors accent;
  final SidebarColors sidebar;

  const ColorsPalette({
    required this.base,
    required this.background,
    required this.border,
    required this.text,
    required this.accent,
    required this.sidebar,
  });
}

class BsColors {
  final Color transparent;
  const BsColors({required this.transparent});
}

class BackgroundColors {
  final Color canvas;
  final Color surface;
  final Color surfaceMuted;

  const BackgroundColors({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
  });
}

class BorderColors {
  final Color primary;
  final Color hover;
  final Color focus;

  const BorderColors({
    required this.primary,
    required this.hover,
    required this.focus,
  });
}

class TextColors {
  final Color primary;
  final Color secondary;
  final Color secondary2;
  final Color muted;

  const TextColors({
    required this.primary,
    required this.secondary,
    required this.secondary2,
    required this.muted,
  });
}

class AccentColors {
  final Color primary;
  final Color primaryMuted;
  final Color danger;
  final Color success;
  final Color warning;
  final Color nav;

  const AccentColors({
    required this.primary,
    required this.primaryMuted,
    required this.danger,
    required this.success,
    required this.warning,
    required this.nav,
  });
}

class SidebarColors {
  final Color border;
  final Color iconBg;
  final Color icon;
  final Color textPrimary;
  final Color arrow;
  final Color sectionLabel;
  final Color textSecondary;
  final Color textMuted;

  const SidebarColors({
    required this.border,
    required this.iconBg,
    required this.icon,
    required this.textPrimary,
    required this.arrow,
    required this.sectionLabel,
    required this.textSecondary,
    required this.textMuted,
  });
}
