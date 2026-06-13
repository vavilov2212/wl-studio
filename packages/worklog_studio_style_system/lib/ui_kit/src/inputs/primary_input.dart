import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrimaryInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? label;
  final String hintText;
  final String? description;
  final Widget? prefixWidget;
  final double? prefixIconPadding;
  final Widget? suffixWidget;
  final double? suffixIconPadding;
  final TextInputType keyboardType;
  final InputState state;
  final bool autofocus;
  final bool enabled;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  // Controls whether the maxLength counter (e.g. "0/7") is shown
  final bool showCounter;
  final InputVariant variant;

  const PrimaryInput({
    required this.label,
    required this.hintText,
    required this.controller,
    this.focusNode,
    this.description,
    this.prefixWidget,
    this.prefixIconPadding,
    this.suffixWidget,
    this.suffixIconPadding,
    this.state = InputState.enabled,
    this.variant = InputVariant.outline,
    this.autofocus = false,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.maxLength,
    this.inputFormatters,
    this.showCounter = false,
    super.key,
  });

  @override
  State<PrimaryInput> createState() => _PrimaryInputState();
}

class _PrimaryInputState extends State<PrimaryInput> {
  TextEditingController get controller => widget.controller;
  ColorsPalette get palette => context.theme.colorsPalette;
  bool hasFocus = false;
  bool isHovered = false;

  Color get backgroundColor {
    if (widget.variant == InputVariant.ghost) return Colors.transparent;
    return switch (widget.state) {
      InputState.enabled =>
        hasFocus ? palette.background.surface : palette.background.surfaceMuted,
      InputState.warning => palette.background.surface,
      InputState.error => palette.background.surface,
      InputState.disabled => palette.background.surfaceMuted,
    };
  }

  BoxBorder? get border {
    if (widget.variant == InputVariant.ghost) return null;
    return switch (widget.state) {
      InputState.enabled => hasFocus
          ? Border.all(color: palette.border.focus)
          : isHovered
              ? Border.all(color: palette.border.hover)
              : null,
      InputState.warning => Border.all(color: palette.accent.warning),
      InputState.error => Border.all(color: palette.accent.danger),
      InputState.disabled => null,
    };
  }

  Color get labelColor => switch (widget.state) {
    InputState.enabled => palette.text.primary,
    InputState.warning => palette.accent.warning,
    InputState.error => palette.accent.danger,
    InputState.disabled => palette.text.muted,
  };

  Color get descriptionColor => switch (widget.state) {
    InputState.enabled => palette.text.secondary,
    InputState.warning => palette.accent.warning,
    InputState.error => palette.accent.danger,
    InputState.disabled => palette.text.muted,
  };

  Color get textColor => switch (widget.state) {
    InputState.enabled => palette.text.primary,
    InputState.warning => palette.accent.warning,
    InputState.error => palette.accent.danger,
    InputState.disabled => palette.text.muted,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: context.theme.spacings.sm,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Text(
            widget.label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: context.theme.commonTextStyles.caption.copyWith(
              color: labelColor,
            ),
          ),
        MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: Focus(
            onFocusChange: (focus) => setState(() => hasFocus = focus),
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: kThemeAnimationDuration,
                height: context.theme.spacings.x4l,
                padding: EdgeInsets.symmetric(
                  horizontal: context.theme.spacings.md,
                ),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: context.theme.radiuses.md.circular,
                  border: border,
                ),
                child: Row(
                  spacing: context.theme.spacings.md,
                  children: [
                    if (widget.prefixWidget != null)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical:
                              widget.prefixIconPadding ??
                              context.theme.spacings.md,
                        ),
                        child: widget.prefixWidget,
                      ),
                    Expanded(
                      child: TextField(
                        focusNode: widget.focusNode,
                        autofocus: widget.autofocus,
                        controller: controller,
                        enabled:
                            widget.enabled && widget.state != InputState.disabled,
                        maxLength: widget.maxLength,
                        inputFormatters: widget.inputFormatters,
                        keyboardType: widget.keyboardType,
                        cursorColor: palette.border.focus,
                        decoration: InputDecoration(
                          isDense: false,
                          border: InputBorder.none,
                          hintText: widget.hintText,
                          hintStyle: context.theme.commonTextStyles.body.copyWith(
                            color: palette.text.muted,
                          ),
                          counterText: widget.showCounter ? null : '',
                        ),
                        style: context.theme.commonTextStyles.body.copyWith(
                          color: textColor,
                        ),
                        strutStyle: const StrutStyle(
                          forceStrutHeight: true,
                          height: 1.2,
                        ),
                        onChanged: (value) {
                          widget.onChanged?.call(value);
                        },
                        onSubmitted: widget.onSubmitted,
                      ),
                    ),
                    if (widget.suffixWidget != null)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical:
                              widget.suffixIconPadding ??
                              context.theme.spacings.md,
                        ),
                        child: widget.suffixWidget,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.description != null)
          Text(
            widget.description!,
            style: context.theme.commonTextStyles.caption2.copyWith(
              color: descriptionColor,
            ),
          ),
      ],
    );
  }
}

enum InputState { enabled, warning, error, disabled }

enum InputVariant { outline, ghost }
