import 'package:flutter/material.dart';

import 'popover_controller.dart';

/// PRIMITIVE: Отвечает ТОЛЬКО за Overlay и позиционирование.
/// Никаких стилей, теней и рамок.
class PopoverPrimitive extends StatefulWidget {
  final Widget trigger; // Кнопка, инпут или иконка
  final WidgetBuilder contentBuilder; // То, что всплывает
  final PopoverController controller;
  final VoidCallback? onRequestClose;
  final Offset offset;
  final double? width; // Если null, ширина равна ширине контента
  final bool
  matchTriggerWidth; // Для Select/Combobox (ширина списка = ширине инпута)
  final double? minWidth;
  final Alignment targetAnchor;
  final Alignment followerAnchor;
  final Object? tapRegionGroupId;

  const PopoverPrimitive({
    Key? key,
    required this.trigger,
    required this.contentBuilder,
    required this.controller,
    this.onRequestClose,
    this.offset = const Offset(0, 4), // Небольшой отступ по дефолту
    this.width,
    this.matchTriggerWidth = false,
    this.minWidth,
    this.targetAnchor = Alignment.bottomLeft,
    this.followerAnchor = Alignment.topLeft,
    this.tapRegionGroupId,
  }) : super(key: key);

  @override
  State<PopoverPrimitive> createState() => _PopoverPrimitiveState();
}

class _PopoverPrimitiveState extends State<PopoverPrimitive> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late PopoverController _controller;
  late Object _internalTapRegionGroupId;

  @override
  void initState() {
    super.initState();
    _internalTapRegionGroupId = widget.tapRegionGroupId ?? Object();
    _controller = widget.controller;
    _controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(PopoverPrimitive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_onChange);
      _controller = widget.controller;
      _controller.addListener(_onChange);
    }
    if (widget.tapRegionGroupId != oldWidget.tapRegionGroupId) {
      _internalTapRegionGroupId = widget.tapRegionGroupId ?? Object();
    }

    // Rebuild the overlay if the widget updates (e.g., contentBuilder changes)
    if (_overlayEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _overlayEntry != null) {
          _overlayEntry!.markNeedsBuild();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _overlayEntry?.remove();
    super.dispose();
  }

  void _onChange() {
    _controller.isOpen ? _show() : _hide();
  }

  void _show() {
    if (_overlayEntry != null) return;

    // Получаем размер триггера, чтобы подогнать ширину (нужно для Select)
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final triggerWidth = renderBox?.size.width ?? 200.0;
    final minWidth = widget.minWidth;
    final effectiveWidth = widget.matchTriggerWidth
        ? (minWidth != null && minWidth > triggerWidth ? minWidth : triggerWidth)
        : widget.width;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Сам Popover
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: widget.targetAnchor,
              followerAnchor: widget.followerAnchor,
              offset: widget.offset,
              child: Align(
                alignment: widget.followerAnchor,
                child: SizedBox(
                  width: effectiveWidth,
                  child: Material(
                    type: MaterialType.transparency,
                    child: TapRegion(
                      groupId: _internalTapRegionGroupId,
                      onTapOutside: (_) {
                        if (widget.onRequestClose != null) {
                          widget.onRequestClose!();
                        } else {
                          _controller.hide();
                        }
                      },
                      child: widget.contentBuilder(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _internalTapRegionGroupId,
      child: CompositedTransformTarget(link: _layerLink, child: widget.trigger),
    );
  }
}
