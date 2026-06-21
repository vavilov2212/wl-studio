import 'package:flutter/material.dart';
import '../popover/popover.dart';
import 'combobox_controller.dart';

class Combobox extends StatefulWidget {
  final ComboboxController? controller;

  /// triggerBuilder:
  /// open() — открыть
  /// isOpen — текущее состояние
  final Widget Function(BuildContext context, VoidCallback open, bool isOpen)
  triggerBuilder;

  /// contentBuilder:
  /// close() — закрыть
  final Widget Function(BuildContext context, VoidCallback close)
  contentBuilder;

  final bool enabled;

  final Offset offset;
  final double? width;
  final bool matchTriggerWidth;
  final double? minWidth;
  final Object? tapRegionGroupId;

  const Combobox({
    super.key,
    this.controller,
    required this.triggerBuilder,
    required this.contentBuilder,
    this.enabled = true,
    this.offset = const Offset(0, 4),
    this.width,
    this.matchTriggerWidth = false,
    this.minWidth,
    this.tapRegionGroupId,
  });

  @override
  State<Combobox> createState() => _ComboboxState();
}

class _ComboboxState extends State<Combobox> {
  late final ComboboxController _internalController;
  late ComboboxController _controller;

  final PopoverController _popoverController = PopoverController();

  bool _isInternal = false;

  @override
  void initState() {
    super.initState();

    _initController();
    _controller.addListener(_handleControllerChange);
  }

  void _initController() {
    if (widget.controller == null) {
      _internalController = ComboboxController();
      _controller = _internalController;
      _isInternal = true;
    } else {
      _controller = widget.controller!;
      _isInternal = false;
    }
  }

  @override
  void didUpdateWidget(covariant Combobox oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChange);
      if (_isInternal) {
        _internalController.dispose();
      }

      _initController();
      _controller.addListener(_handleControllerChange);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChange);

    if (_isInternal) {
      _internalController.dispose();
    }

    _popoverController.dispose();

    super.dispose();
  }

  void _handleControllerChange() {
    if (_controller.isOpen) {
      _popoverController.show();
    } else {
      _popoverController.hide();
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopoverPrimitive(
      controller: _popoverController,
      onRequestClose: _controller.close,
      offset: widget.offset,
      width: widget.width,
      matchTriggerWidth: widget.matchTriggerWidth,
      minWidth: widget.minWidth,
      tapRegionGroupId: widget.tapRegionGroupId,
      trigger: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.enabled ? _controller.toggle : null,
        child: widget.triggerBuilder(
          context,
          _controller.open,
          _controller.isOpen,
        ),
      ),
      contentBuilder: (context) {
        return widget.contentBuilder(context, _controller.close);
      },
    );
  }
}
