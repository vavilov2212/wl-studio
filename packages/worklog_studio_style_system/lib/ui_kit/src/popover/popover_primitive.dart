import 'package:flutter/material.dart';

import 'popover_controller.dart';

/// PRIMITIVE: Отвечает ТОЛЬКО за Overlay и позиционирование.
/// Никаких стилей, теней и рамок.
///
/// Positioning uses a flip+shift strategy (the same idea as Floating UI's
/// `flip`/`shift` middleware): [targetAnchor]/[followerAnchor] describe the
/// *preferred* side, but if the popover would overflow the window on that
/// side, it flips to the opposite side, and as a last resort gets shifted
/// back into the viewport so it is always fully visible.
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
  OverlayEntry? _overlayEntry;
  late PopoverController _controller;
  late Object _internalTapRegionGroupId;
  final GlobalKey _triggerKey = GlobalKey();

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

  Rect? _anchorRect(RenderBox overlayBox) {
    final triggerBox = _triggerKey.currentContext?.findRenderObject();
    if (triggerBox is! RenderBox || !triggerBox.attached) return null;
    final topLeft = triggerBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      triggerBox.size.width,
      triggerBox.size.height,
    );
  }

  void _show() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final overlayBox = Overlay.of(context).context.findRenderObject();
        final anchorRect = overlayBox is RenderBox
            ? _anchorRect(overlayBox)
            : null;
        if (anchorRect == null) return const SizedBox.shrink();

        return Stack(
          children: [
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _PopoverLayoutDelegate(
                  anchorRect: anchorRect,
                  offset: widget.offset,
                  targetAnchor: widget.targetAnchor,
                  followerAnchor: widget.followerAnchor,
                  width: widget.width,
                  matchTriggerWidth: widget.matchTriggerWidth,
                  minWidth: widget.minWidth,
                ),
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
      child: KeyedSubtree(key: _triggerKey, child: widget.trigger),
    );
  }
}

/// Lays the popover out against [anchorRect] (the trigger's bounds in the
/// Overlay's coordinate space), preferring the side described by
/// [targetAnchor]/[followerAnchor] but flipping to the opposite side when
/// there isn't enough room, then clamping (shifting) the result back inside
/// the viewport so the popover never renders off-screen.
class _PopoverLayoutDelegate extends SingleChildLayoutDelegate {
  static const double _screenMargin = 8;

  final Rect anchorRect;
  final Offset offset;
  final Alignment targetAnchor;
  final Alignment followerAnchor;
  final double? width;
  final bool matchTriggerWidth;
  final double? minWidth;

  _PopoverLayoutDelegate({
    required this.anchorRect,
    required this.offset,
    required this.targetAnchor,
    required this.followerAnchor,
    required this.width,
    required this.matchTriggerWidth,
    required this.minWidth,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = (constraints.maxWidth - _screenMargin * 2).clamp(
      0.0,
      constraints.maxWidth,
    );
    final maxHeight = (constraints.maxHeight - _screenMargin * 2).clamp(
      0.0,
      constraints.maxHeight,
    );

    double minWidthValue = 0;
    double maxWidthValue = maxWidth;

    if (matchTriggerWidth) {
      minWidthValue = anchorRect.width;
      if (minWidth != null && minWidth! > minWidthValue) {
        minWidthValue = minWidth!;
      }
      minWidthValue = minWidthValue.clamp(0.0, maxWidth);
      maxWidthValue = minWidthValue;
    } else if (width != null) {
      minWidthValue = width!.clamp(0.0, maxWidth);
      maxWidthValue = minWidthValue;
    }

    return BoxConstraints(
      minWidth: minWidthValue,
      maxWidth: maxWidthValue,
      minHeight: 0,
      maxHeight: maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final preferBelow = targetAnchor.y >= 0;
    final preferRightAligned = followerAnchor.x > 0;

    final spaceBelow = size.height - _screenMargin - anchorRect.bottom;
    final spaceAbove = anchorRect.top - _screenMargin;

    bool placeBelow = preferBelow;
    if (preferBelow && childSize.height > spaceBelow && spaceAbove > spaceBelow) {
      placeBelow = false;
    } else if (!preferBelow && childSize.height > spaceAbove && spaceBelow > spaceAbove) {
      placeBelow = true;
    }

    double y = placeBelow
        ? anchorRect.bottom + offset.dy
        : anchorRect.top - childSize.height - offset.dy;

    final referenceX = targetAnchor.x <= 0 ? anchorRect.left : anchorRect.right;
    final spaceRight = size.width - _screenMargin - anchorRect.left;
    final spaceLeft = anchorRect.right - _screenMargin;

    bool alignRight = preferRightAligned;
    if (!preferRightAligned && childSize.width > spaceRight && spaceLeft > spaceRight) {
      alignRight = true;
    } else if (preferRightAligned && childSize.width > spaceLeft && spaceRight > spaceLeft) {
      alignRight = false;
    }

    double x = alignRight
        ? referenceX - childSize.width + offset.dx
        : referenceX + offset.dx;

    final minX = _screenMargin;
    final maxX = (size.width - _screenMargin - childSize.width).clamp(
      minX,
      double.infinity,
    );
    final minY = _screenMargin;
    final maxY = (size.height - _screenMargin - childSize.height).clamp(
      minY,
      double.infinity,
    );

    x = x.clamp(minX, maxX);
    y = y.clamp(minY, maxY);

    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PopoverLayoutDelegate oldDelegate) {
    return anchorRect != oldDelegate.anchorRect ||
        offset != oldDelegate.offset ||
        targetAnchor != oldDelegate.targetAnchor ||
        followerAnchor != oldDelegate.followerAnchor ||
        width != oldDelegate.width ||
        matchTriggerWidth != oldDelegate.matchTriggerWidth ||
        minWidth != oldDelegate.minWidth;
  }
}
