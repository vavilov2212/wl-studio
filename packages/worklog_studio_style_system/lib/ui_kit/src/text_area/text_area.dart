import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

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
  final ControlSize size;
  final ValueChanged<String>? onChanged;

  const TextArea({
    required this.hintText,
    required this.controller,
    this.label,
    this.enabled = true,
    this.autofocus = false,
    this.hasError = false,
    this.showCounter = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 5,
    this.maxLength = 3000,
    this.size = ControlSize.sm,
    this.onChanged,
    super.key,
  });

  @override
  State<TextArea> createState() => _TextAreaState();
}

class _TextAreaState extends State<TextArea> {
  TextEditingController get controller => widget.controller;
  get palette => context.theme.colorsPalette;
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
    final tokens = theme.controlSize(widget.size);

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
                minHeight: tokens.height,
                maxHeight: 500,
              ),
              height: _manualHeight,
              decoration: BoxDecoration(
                color: palette.background.surface,
                borderRadius: theme.radiuses.md.circular,
                border: Border.all(color: _borderColor),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: tokens.allPadding,
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
                        hintStyle: tokens.textStyle.copyWith(
                          color: palette.text.muted,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: null,
                      maxLength: widget.maxLength,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            required maxLength,
                          }) => const SizedBox.shrink(),
                      style: tokens.textStyle.copyWith(color: _textColor),
                      onChanged: (val) {
                        if (widget.onChanged != null) {
                          widget.onChanged!(val);
                        }
                      },
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 12,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) {
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
                              tokens.height;
                          _manualHeight = (currentHeight + details.delta.dy)
                              .clamp(tokens.height, 500.0);
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
