import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:flutter/material.dart';
import 'package:vector_svg/vector_svg.dart';

class PrimaryButton extends StatefulWidget {
  final String? title;
  final String? leftIcon;
  final String? rightIcon;
  final Widget? leftIconWidget;
  final Widget? rightIconWidget;
  final ButtonType type;
  final ButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback? onTap;
  final AlignmentGeometry? alignment;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Duration initialAnimationDuration;

  const PrimaryButton({
    required this.onTap,
    this.title,
    this.leftIcon,
    this.rightIcon,
    this.leftIconWidget,
    this.rightIconWidget,
    this.type = ButtonType.primary,
    this.size = ButtonSize.md,
    this.isLoading = false,
    this.isDisabled = false,
    this.alignment,
    this.backgroundColor,
    this.foregroundColor,
    this.initialAnimationDuration = const Duration(milliseconds: 20),
    super.key,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool isActive = false;
  bool isHovered = false;
  bool get isDisabled => widget.isDisabled || widget.onTap == null;

  bool get _isHoverApplied => isHovered && !isDisabled && !isActive;

  Color _darken(Color color, [double amount = 0.08]) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  EdgeInsetsGeometry get innerPadding {
    return switch (widget.size) {
      ButtonSize.sm => EdgeInsets.symmetric(
        vertical: context.theme.spacings.sm,
        horizontal: context.theme.spacings.md,
      ),
      ButtonSize.md => EdgeInsets.symmetric(
        vertical: context.theme.spacings.sm,
        horizontal: context.theme.spacings.lg,
      ),
      ButtonSize.lg => EdgeInsets.symmetric(
        vertical: context.theme.spacings.sm,
        horizontal: context.theme.spacings.x2l,
      ),
    };
  }

  double get height {
    return switch (widget.size) {
      ButtonSize.sm => 36,
      ButtonSize.md => 40,
      ButtonSize.lg => 44,
    };
  }

  BorderRadiusGeometry get borderRadius {
    return context.theme.radiuses.sm.circular;
  }

  BoxBorder? get border {
    return switch (widget.type) {
      ButtonType.secondary => BoxBorder.all(
        color: context.theme.colorsPalette.border.primary,
        width: 1,
        style: BorderStyle.solid,
        strokeAlign: BorderSide.strokeAlignInside,
      ),
      _ => null,
    };
  }

  double get iconDimension {
    return switch (widget.size) {
      ButtonSize.sm => 14,
      ButtonSize.md => 18,
      ButtonSize.lg => 22,
    };
  }

  TextStyle get textStyle {
    return switch (widget.size) {
      ButtonSize.sm => context.theme.commonTextStyles.buttonS,
      ButtonSize.md => context.theme.commonTextStyles.buttonM,
      ButtonSize.lg => context.theme.commonTextStyles.buttonL,
    };
  }

  Widget? buildIcon(String? iconPath) {
    return iconPath?.vector(
      width: iconDimension,
      height: iconDimension,
      colorFilter: foregroundColor.filter,
    );
  }

  List<BoxShadow>? get boxShadow {
    if (isActive || isDisabled) return [context.theme.shadows.none];

    return switch (widget.type) {
      ButtonType.primary => [context.theme.shadows.sm],
      _ => [context.theme.shadows.none],
    };
  }

  Gradient? get backgroundGradient {
    if (isDisabled || isActive) return null;
    if (widget.type == ButtonType.primary) {
      final base = context.theme.colorsPalette.accent.primary;
      final start = _isHoverApplied ? _darken(base) : base;
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [start, start.withValues(alpha: 0.8)],
      );
    }
    return null;
  }

  Color get backgroundColor {
    if (isDisabled) return context.theme.colorsPalette.background.surfaceMuted;

    final base = widget.backgroundColor ??
        switch (widget.type) {
          ButtonType.primary =>
            isActive
                ? context.theme.colorsPalette.accent.primary.withValues(alpha: 0.75)
                : context.theme.colorsPalette.accent.primary,
          ButtonType.secondary =>
            isActive
                ? context.theme.colorsPalette.background.surface
                : context.theme.colorsPalette.background.surfaceMuted,
          ButtonType.danger => context.theme.colorsPalette.accent.danger,
          ButtonType.warning => context.theme.colorsPalette.accent.warning,
          ButtonType.success => context.theme.colorsPalette.accent.success,
          ButtonType.ghost =>
            isActive
                ? context.theme.colorsPalette.background.surfaceMuted
                : context.theme.colorsPalette.base.transparent,
        };

    if (!_isHoverApplied) return base;

    // Ghost is transparent at rest — darkening a transparent color is a
    // no-op, so give it a faint surface tint instead for the same sense
    // of depth on hover.
    if (base.a == 0) {
      return context.theme.colorsPalette.background.surfaceMuted;
    }
    return _darken(base);
  }

  Color get foregroundColor {
    if (isDisabled) return context.theme.colorsPalette.text.muted;

    return widget.foregroundColor ??
        switch (widget.type) {
          ButtonType.primary =>
            isActive
                ? context.theme.colorsPalette.text.primary
                : context.theme.colorsPalette.background.surface,
          ButtonType.secondary => context.theme.colorsPalette.accent.primary,
          ButtonType.danger => context.theme.colorsPalette.background.surface,
          ButtonType.warning => context.theme.colorsPalette.background.surface,
          ButtonType.success => context.theme.colorsPalette.background.surface,
          ButtonType.ghost =>
            isActive
                ? context.theme.colorsPalette.text.secondary
                : context.theme.colorsPalette.text.primary,
        };
  }

  Widget _wrapIcon(Widget icon) {
    return SizedBox(
      width: iconDimension,
      height: iconDimension,
      child: IconTheme(
        data: IconThemeData(color: foregroundColor, size: iconDimension),
        child: icon,
      ),
    );
  }

  void _onTap() {
    if (widget.isLoading) return;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.isDisabled ? null : _onTap,
        onTapDown: (_) => setState(() => isActive = true),
        onTapCancel: () => setState(() => isActive = false),
        onTapUp: (_) => setState(() => isActive = false),
        child: AnimatedContainer(
          duration: widget.initialAnimationDuration,
          decoration: BoxDecoration(
            color: backgroundGradient == null ? backgroundColor : null,
            gradient: backgroundGradient,
            boxShadow: boxShadow,
            borderRadius: borderRadius,
            border: border,
          ),
          padding: innerPadding,
          alignment: widget.alignment ?? Alignment.center,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: widget.type == ButtonType.ghost && widget.isLoading
                    ? 0
                    : 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.leftIconWidget != null)
                      _wrapIcon(widget.leftIconWidget!)
                    else if (widget.leftIcon != null)
                      buildIcon(widget.leftIcon)!,
                    if (widget.title != null) ...[
                      SizedBox(width: context.theme.spacings.sm),
                      Flexible(
                        child: Text(
                          widget.title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: textStyle.copyWith(color: foregroundColor),
                        ),
                      ),
                    ],
                    if (widget.rightIconWidget != null)
                      _wrapIcon(widget.rightIconWidget!)
                    else if (widget.rightIcon != null)
                      buildIcon(widget.rightIcon)!,
                  ],
                ),
              ),
              Positioned.fill(
                child: AnimatedCrossFade(
                  firstChild: SizedBox.shrink(),
                  secondChild: ColoredBox(
                    color: backgroundColor,
                    child: Center(
                      child: RotatingIcon(
                        child: buildIcon(
                          WorklogStudioAssets.vectors.rotateClockwise24Svg,
                        )!,
                      ),
                    ),
                  ),
                  crossFadeState: widget.isLoading
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: kThemeAnimationDuration,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum ButtonType { primary, secondary, danger, success, warning, ghost }

enum ButtonSize { sm, md, lg }

class RotatingIcon extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const RotatingIcon({
    required this.child,
    super.key,
    this.duration = const Duration(seconds: 1),
    this.curve = Curves.fastOutSlowIn,
  });

  @override
  State<RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<RotatingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> animation;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat();
    animation = CurvedAnimation(parent: controller, curve: widget.curve);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: animation, child: widget.child);
  }
}
