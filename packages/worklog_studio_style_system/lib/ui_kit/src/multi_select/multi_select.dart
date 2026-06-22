import 'dart:async';
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

import '../combobox/combobox_controller.dart';
import '../select/select_trigger.dart';

class MultiSelect<T> extends StatefulWidget {
  final List<T> value;
  final ValueChanged<List<T>>? onChanged;
  final List<SelectOption<T>> options;
  final String placeholder;
  final bool searchable;
  final bool enabled;
  final ComboboxController? controller;
  final ControlSize size;
  final bool matchTriggerWidth;
  final double? minWidth;
  final Widget Function(
    BuildContext context,
    List<SelectOption<T>> selectedOptions,
    bool isOpen,
  )?
  triggerBuilder;
  final Object? tapRegionGroupId;

  const MultiSelect({
    super.key,
    required this.value,
    this.onChanged,
    required this.options,
    this.placeholder = 'Select options...',
    this.searchable = false,
    this.enabled = true,
    this.controller,
    this.size = ControlSize.sm,
    this.matchTriggerWidth = true,
    this.minWidth = 240,
    this.triggerBuilder,
    this.tapRegionGroupId,
  });

  @override
  State<MultiSelect<T>> createState() => _MultiSelectState<T>();
}

class _MultiSelectState<T> extends State<MultiSelect<T>> {
  late ComboboxController _controller;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ComboboxController();
    _searchController.addListener(_onSearchChanged);
    _controller.addListener(_handleOpenChange);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _searchQuery != _searchController.text) {
        setState(() => _searchQuery = _searchController.text);
      }
    });
  }

  void _handleOpenChange() {
    if (!_controller.isOpen) {
      _searchController.clear();
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  @override
  void didUpdateWidget(covariant MultiSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_handleOpenChange);
      if (oldWidget.controller == null) {
        _controller.dispose();
      }
      _controller = widget.controller ?? ComboboxController();
      _controller.addListener(_handleOpenChange);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_handleOpenChange);
    if (widget.controller == null) {
      _controller.dispose();
    }
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleValue(T value) {
    final next = List<T>.from(widget.value);
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final selectedOptions = widget.options
        .where((o) => widget.value.contains(o.value))
        .toList();

    return Combobox(
      controller: _controller,
      enabled: widget.enabled,
      matchTriggerWidth: widget.matchTriggerWidth,
      minWidth: widget.minWidth,
      tapRegionGroupId: widget.tapRegionGroupId,
      triggerBuilder: (context, open, isOpen) {
        if (widget.triggerBuilder != null) {
          return widget.triggerBuilder!(context, selectedOptions, isOpen);
        }
        final label = selectedOptions.isEmpty
            ? null
            : selectedOptions.length == 1
            ? selectedOptions.first.label
            : '${selectedOptions.length} selected';
        return SelectTrigger(
          label: label,
          placeholder: widget.placeholder,
          controller: widget.searchable ? _searchController : null,
          focusNode: widget.searchable ? _focusNode : null,
          isOpen: isOpen,
          size: widget.size,
        );
      },
      contentBuilder: (context, close) {
        return MultiSelectContent<T>(
          searchable: widget.searchable,
          options: widget.options,
          selectedValues: widget.value,
          onToggle: _toggleValue,
          searchQuery: _searchQuery,
          size: widget.size,
        );
      },
    );
  }
}
