import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'inline_field_controller.dart';

class InlineField extends StatefulWidget {
  final String label;
  final String value;
  final String placeholder;
  final Widget editWidget;
  final bool isTextArea;
  final InlineFieldController controller;
  final TextEditingController? textController;
  final Widget? leading;
  final Widget? trailing;
  final bool isEditable;
  final ControlSize size;
  final int? viewModeMaxLines;

  const InlineField({
    super.key,
    required this.label,
    required this.value,
    this.placeholder = 'Empty',
    required this.editWidget,
    this.isTextArea = false,
    required this.controller,
    this.textController,
    this.leading,
    this.trailing,
    this.isEditable = true,
    this.size = ControlSize.sm,
    this.viewModeMaxLines,
  });

  @override
  State<InlineField> createState() => _InlineFieldState();
}

class _InlineFieldState extends State<InlineField> {
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    widget.textController?.addListener(_onTextControllerChange);
  }

  void _onTextControllerChange() {
    setState(() {});
  }

  String get _displayValue {
    if (widget.textController != null) {
      return widget.textController!.text;
    }
    if (_currentIsEditing) {
      return widget.controller.currentValue ?? widget.value;
    }
    return widget.controller.currentValue ?? widget.value;
  }

  @override
  void didUpdateWidget(InlineField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onControllerChange);
      widget.controller.addListener(_onControllerChange);
    }
    if (widget.textController != oldWidget.textController) {
      oldWidget.textController?.removeListener(_onTextControllerChange);
      widget.textController?.addListener(_onTextControllerChange);
    }
    if (widget.value != oldWidget.value) {
      widget.controller.resetValue();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    widget.textController?.removeListener(_onTextControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    setState(() {});
  }

  bool get _currentIsEditing => widget.controller.isEditing;

  void _handleTap() {
    if (!widget.isEditable) return;
    widget.controller.enterEditMode(widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final tokens = theme.controlSize(widget.size);

    Widget content = MouseRegion(
      onEnter: (_) {
        if (widget.isEditable) setState(() => _isHovered = true);
      },
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.isEditable
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacings.none),
              child: Text(
                widget.label,
                style: theme.commonTextStyles.labelSmall.copyWith(
                  color: _isHovered || _currentIsEditing
                      ? palette.text.secondary
                      : palette.text.secondary2,
                ),
              ),
            ),
            SizedBox(height: theme.spacings.sm),
            if (widget.isTextArea && _currentIsEditing)
              widget.editWidget
            else
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // View Mode (Base Layer)
                  // Always rendered with Visibility(maintainSize: true) to ensure layout stability
                  Visibility(
                    visible: !_currentIsEditing,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Container(
                      width: double.infinity,
                      height: (!widget.isTextArea && widget.size == ControlSize.sm)
                          ? tokens.height
                          : null,
                      constraints: widget.isTextArea
                          ? BoxConstraints(minHeight: tokens.height)
                          : null,
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.horizontalPadding,
                        vertical: tokens.verticalPadding,
                      ),
                      decoration: BoxDecoration(
                        color: _isHovered && widget.isEditable
                            ? palette.background.surfaceMuted
                            : Colors.transparent,
                        borderRadius: theme.radiuses.md.circular,
                        // Add transparent border to match edit mode's border size
                        border: Border.all(color: Colors.transparent),
                      ),
                      child: Row(
                        spacing: theme.spacings.sm,
                        children: [
                          if (widget.leading != null) widget.leading!,
                          Expanded(
                            child: Text(
                              _displayValue.isEmpty
                                  ? widget.placeholder
                                  : _displayValue,
                              style: tokens.textStyle
                                  .copyWith(
                                color: _displayValue.isEmpty
                                    ? palette.text.muted
                                    : (widget.isEditable
                                          ? palette.text.primary
                                          : palette.text.secondary.withValues(
                                              alpha: 0.5,
                                            )),
                                fontStyle: _displayValue.isEmpty
                                    ? FontStyle.italic
                                    : null,
                              ),
                              maxLines: widget.isTextArea
                                  ? widget.viewModeMaxLines
                                  : 1,
                              overflow: widget.isTextArea
                                  ? (widget.viewModeMaxLines != null
                                        ? TextOverflow.ellipsis
                                        : null)
                                  : TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.isEditable)
                            Visibility(
                              visible: _isHovered,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: Icon(
                                Icons.edit_sharp,
                                color: palette.text.secondary,
                                size: 16.0,
                              ),
                            ),
                          if (widget.trailing != null) widget.trailing!,
                        ],
                      ),
                    ),
                  ),
                  // Edit Mode (Overlay Layer) - Only for non-TextArea fields
                  if (_currentIsEditing && !widget.isTextArea)
                    Positioned.fill(child: widget.editWidget),
                ],
              ),
          ],
        ),
      ),
    );

    if (_currentIsEditing) {
      return TapRegion(
        groupId: widget.controller.tapRegionGroupId,
        onTapOutside: (_) {
          widget.controller.handleEditorCommit();
        },
        child: content,
      );
    }

    return content;
  }
}
