import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'package:worklog_studio_style_system/theme/radiuses.dart';
import 'package:worklog_studio_style_system/theme/theme_extension/app_theme_extension.dart';

class TextArea extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final String hintText;
  final TextInputType keyboardType;
  final bool enabled;
  final bool hasError;
  final bool autofocus;
  final int maxLength;
  final int? maxLines;
  final bool showCounter;
  final ValueChanged<String>? onChanged;

  const TextArea({
    required this.hintText,
    required this.controller,
    this.label,
    this.enabled = true,
    this.autofocus = false,
    this.hasError = false,
    this.showCounter = true,
    this.keyboardType = TextInputType.text,
    this.maxLines = 5,
    this.maxLength = 3000,
    this.onChanged,
    super.key,
  });

  @override
  State<TextArea> createState() => _TextAreaState();
}

class _TextAreaState extends State<TextArea> {
  TextEditingController get controller => widget.controller;
  ColorsPalette get palette => context.theme.colorsPalette;
  bool _hasFocus = false;
  double? _manualHeight;
  bool _isResizing = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Color get _borderColor {
    if (!widget.enabled) return palette.border.primary;
    if (_hasFocus) return palette.border.focus;
    return palette.border.primary;
  }

  Color get _labelColor {
    if (!widget.enabled) return palette.text.muted;
    return palette.text.primary;
  }

  Color get _counterColor {
    if (!widget.enabled) return palette.text.muted;
    return palette.text.secondary;
  }

  Color get _textColor {
    if (!widget.enabled) return palette.text.muted;
    return palette.text.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: theme.spacings.sm,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Text(
            widget.label!,
            style: theme.commonTextStyles.caption.copyWith(color: _labelColor),
          ),
        Focus(
          onFocusChange: (focus) {
            if (_isResizing) return;
            setState(() => _hasFocus = focus);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _focusNode.requestFocus(),
            child: Container(
              constraints: BoxConstraints(
                minHeight: theme.spacings.x4l,
                maxHeight: 500,
              ),
              height: _manualHeight,
              decoration: BoxDecoration(
                color: palette.background.surface,
                borderRadius: theme.radiuses.sm.circular,
                border: Border.all(color: _borderColor),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.all(theme.spacings.lg),
                    child: TextField(
                      autofocus: widget.autofocus,
                      controller: controller,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      keyboardType: widget.keyboardType,
                      cursorColor: palette.text.primary,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: widget.hintText,
                        hintStyle: theme.commonTextStyles.body.copyWith(
                          color: palette.text.muted,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: null, // Auto-expand
                      maxLength: widget.maxLength,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            required maxLength,
                          }) => const SizedBox.shrink(),
                      style: theme.commonTextStyles.body.copyWith(
                        color: _textColor,
                      ),
                      onChanged: (val) {
                        if (widget.onChanged != null) {
                          widget.onChanged!(val);
                        }
                      },
                    ),
                  ),
                  // Resize Handle (Bottom Edge)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 12,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) {
                        // Request focus immediately on tap down to prevent blur
                        _focusNode.requestFocus();
                      },
                      onVerticalDragStart: (_) {
                        setState(() => _isResizing = true);
                        _focusNode.requestFocus();
                      },
                      onVerticalDragUpdate: (details) {
                        setState(() {
                          final currentHeight =
                              _manualHeight ??
                              context.size?.height ??
                              theme.spacings.x4l;
                          _manualHeight = (currentHeight + details.delta.dy)
                              .clamp(theme.spacings.x4l, 500.0);
                        });
                      },
                      onVerticalDragEnd: (_) {
                        setState(() => _isResizing = false);
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeUpDown,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            // Visual indicator
                            Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.drag_handle,
                                size: 12,
                                color: palette.text.muted.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.showCounter)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${controller.text.length}/${widget.maxLength}',
              style: theme.commonTextStyles.caption2.copyWith(
                color: _counterColor,
              ),
            ),
          ),
      ],
    );
  }
}
