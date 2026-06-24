# Table Filter Toolbar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Notion-like filter/sort/settings toolbar directly above the table on the History, Tasks, and Projects pages, with working client-side filters (Sort/Settings disabled placeholders).

**Architecture:** Two new reusable ui-kit primitives (`MultiSelect<T>`, `DateRangeButton`) plus a shared `TableToolbar` icon row live in `packages/worklog_studio_style_system`. Each page gets a pure, unit-tested filter-predicate function + immutable filter-state class in `apps/worklog_studio/lib/domain/`, and a small page-specific filter-bar widget that wires the ui-kit primitives to that page's filter set.

**Tech Stack:** Flutter, Provider, existing `Combobox`/`PopoverPrimitive`/`SelectOption` plumbing, `intl` (already a dependency), Flutter's built-in `showDateRangePicker`.

## Global Constraints

- Windows environment, backslash paths, no macos/ios/android/linux/web directories touched.
- Use `fvm` for all Flutter/Dart commands (never bare `flutter`/`dart`).
- Never run `flutter pub get` directly — `fvm exec melos bootstrap` from repo root if dependencies change (none do in this plan).
- Mandatory TDD for all new business logic: write failing test first, minimal implementation, refactor under green. Domain logic tests go in `apps/worklog_studio/test/core/`. UI-only widgets are exempt from the unit-test mandate (manual verification instead).
- Test command: `fvm flutter test test/core/ test/feature/ --reporter expanded` from `apps/worklog_studio/`.
- Never add a `Co-Authored-By: Claude` trailer to commits.
- `domain/` files in `apps/worklog_studio/lib/domain/` must stay Flutter-free (pure Dart, no `package:flutter` imports) — confirmed convention from existing files (`resolved_task.dart`, `resolved_project.dart`, `resolved_time_entry.dart`, `time_entry.dart` all import only other domain files or `dart:io`).

---

### Task 1: `MultiSelect<T>` ui-kit primitive

**Files:**
- Create: `packages/worklog_studio_style_system/lib/ui_kit/src/multi_select/multi_select.dart`
- Create: `packages/worklog_studio_style_system/lib/ui_kit/src/multi_select/multi_select_content.dart`
- Create: `packages/worklog_studio_style_system/lib/ui_kit/src/multi_select/index.dart`
- Modify: `packages/worklog_studio_style_system/lib/ui_kit/ui_kit.dart`

**Interfaces:**
- Consumes: `Combobox` (`ui_kit/src/combobox/combobox.dart`), `ComboboxController` (`ui_kit/src/combobox/combobox_controller.dart`), `SelectOption<T>` (`ui_kit/src/select/select_option.dart`, fields: `value`, `label`, `leading`), `SelectTrigger` (`ui_kit/src/select/select_trigger.dart`, params: `label`, `placeholder`, `controller`, `focusNode`, `isOpen`, `size`), `context.theme` (`spacings`, `radiuses`, `colorsPalette`, `commonTextStyles`, `shadows`, `controlSize(ControlSize)`).
- Produces: `MultiSelect<T>` widget with `value: List<T>`, `onChanged: ValueChanged<List<T>>?`, `options: List<SelectOption<T>>`, `placeholder`, `searchable`, `enabled`, `controller`, `size: ControlSize`, `matchTriggerWidth`, `minWidth`, `triggerBuilder`, `tapRegionGroupId`. Used by Task 7/8/9 filter bars for Task/Project/Status filtering.

- [ ] **Step 1: Create `multi_select_content.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class MultiSelectContent<T> extends StatelessWidget {
  final bool searchable;
  final List<SelectOption<T>> options;
  final List<T> selectedValues;
  final ValueChanged<T> onToggle;
  final String searchQuery;
  final ControlSize size;

  const MultiSelectContent({
    super.key,
    required this.searchable,
    required this.options,
    required this.selectedValues,
    required this.onToggle,
    required this.searchQuery,
    this.size = ControlSize.sm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final filteredOptions = options.where((option) {
      if (!searchable || searchQuery.isEmpty) return true;
      return option.label.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: palette.background.surface,
        borderRadius: theme.radiuses.md.circular,
        border: Border.all(color: palette.border.primary),
        boxShadow: [theme.shadows.md],
      ),
      child: filteredOptions.isEmpty
          ? Padding(
              padding: EdgeInsets.all(theme.spacings.lg),
              child: Text(
                'No results found',
                style: theme.commonTextStyles.body.copyWith(
                  color: palette.text.muted,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: filteredOptions.length,
              itemBuilder: (context, index) {
                final option = filteredOptions[index];
                final isSelected = selectedValues.contains(option.value);
                return _MultiSelectOptionRow<T>(
                  option: option,
                  isSelected: isSelected,
                  size: size,
                  onTap: () => onToggle(option.value),
                );
              },
            ),
    );
  }
}

class _MultiSelectOptionRow<T> extends StatefulWidget {
  final SelectOption<T> option;
  final bool isSelected;
  final ControlSize size;
  final VoidCallback onTap;

  const _MultiSelectOptionRow({
    required this.option,
    required this.isSelected,
    required this.size,
    required this.onTap,
  });

  @override
  State<_MultiSelectOptionRow<T>> createState() =>
      _MultiSelectOptionRowState<T>();
}

class _MultiSelectOptionRowState<T> extends State<_MultiSelectOptionRow<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final tokens = theme.controlSize(widget.size);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.horizontalPadding,
            vertical: tokens.verticalPadding == 0
                ? theme.spacings.sm
                : tokens.verticalPadding,
          ),
          color: _isHovered ? palette.background.surfaceMuted : null,
          child: Row(
            children: [
              Icon(
                widget.isSelected
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: tokens.iconSize,
                color: widget.isSelected
                    ? palette.accent.primary
                    : palette.text.muted,
              ),
              SizedBox(width: theme.spacings.sm),
              if (widget.option.leading != null) ...[
                widget.option.leading!,
                SizedBox(width: theme.spacings.sm),
              ],
              Expanded(
                child: Text(
                  widget.option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.textStyle.copyWith(
                    color: widget.isSelected
                        ? palette.text.primary
                        : palette.text.secondary,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create `multi_select.dart`**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'multi_select_content.dart';

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
```

- [ ] **Step 3: Create `index.dart`**

```dart
export 'multi_select.dart';
export 'multi_select_content.dart';
```

- [ ] **Step 4: Add export to `ui_kit.dart`**

Open `packages/worklog_studio_style_system/lib/ui_kit/ui_kit.dart` and add this line after `export 'src/select/index.dart';`:

```dart
export 'src/multi_select/index.dart';
```

- [ ] **Step 5: Verify it compiles**

Run from `packages/worklog_studio_style_system/`: `fvm flutter analyze lib/ui_kit/src/multi_select/`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add packages/worklog_studio_style_system/lib/ui_kit/src/multi_select/ packages/worklog_studio_style_system/lib/ui_kit/ui_kit.dart
git commit -m "Add MultiSelect ui-kit primitive"
```

---

### Task 2: `DateRangeButton` ui-kit primitive

**Files:**
- Create: `packages/worklog_studio_style_system/lib/ui_kit/src/date_range_button/date_range_button.dart`
- Create: `packages/worklog_studio_style_system/lib/ui_kit/src/date_range_button/index.dart`
- Modify: `packages/worklog_studio_style_system/lib/ui_kit/ui_kit.dart`

**Interfaces:**
- Consumes: `Combobox`, `ComboboxController`, `SelectTrigger`, `context.theme`, `intl`'s `DateFormat`, Flutter's `showDateRangePicker`/`DateTimeRange`.
- Produces: `DateRangeButton` widget with `value: DateTimeRange?`, `onChanged: ValueChanged<DateTimeRange?>`, `placeholder`, `size`. `onChanged(null)` means "All time"/cleared. Used by Task 7/8/9 filter bars for the Date filter.

- [ ] **Step 1: Create `date_range_button.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class DateRangeButton extends StatefulWidget {
  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?> onChanged;
  final String placeholder;
  final ControlSize size;

  const DateRangeButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Date',
    this.size = ControlSize.sm,
  });

  @override
  State<DateRangeButton> createState() => _DateRangeButtonState();
}

class _DateRangeButtonState extends State<DateRangeButton> {
  final ComboboxController _controller = ComboboxController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTimeRange _todayRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTimeRange(start: today, end: today);
  }

  DateTimeRange _thisWeekRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    return DateTimeRange(start: weekStart, end: today);
  }

  DateTimeRange _thisMonthRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(today.year, today.month, 1);
    return DateTimeRange(start: monthStart, end: today);
  }

  Future<void> _pickCustomRange(BuildContext context, VoidCallback close) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: widget.value,
    );
    close();
    if (picked != null) {
      widget.onChanged(picked);
    }
  }

  String? get _label {
    final range = widget.value;
    if (range == null) return null;
    final fmt = DateFormat('MMM d');
    final sameDay =
        range.start.year == range.end.year &&
        range.start.month == range.end.month &&
        range.start.day == range.end.day;
    if (sameDay) return fmt.format(range.start);
    return '${fmt.format(range.start)} – ${fmt.format(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Combobox(
      controller: _controller,
      triggerBuilder: (context, open, isOpen) {
        return SelectTrigger(
          label: _label,
          placeholder: widget.placeholder,
          isOpen: isOpen,
          size: widget.size,
        );
      },
      contentBuilder: (context, close) {
        return Container(
          decoration: BoxDecoration(
            color: palette.background.surface,
            borderRadius: theme.radiuses.md.circular,
            border: Border.all(color: palette.border.primary),
            boxShadow: [theme.shadows.md],
          ),
          padding: EdgeInsets.symmetric(vertical: theme.spacings.xxs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PresetRow(
                label: 'Today',
                onTap: () {
                  widget.onChanged(_todayRange());
                  close();
                },
              ),
              _PresetRow(
                label: 'This week',
                onTap: () {
                  widget.onChanged(_thisWeekRange());
                  close();
                },
              ),
              _PresetRow(
                label: 'This month',
                onTap: () {
                  widget.onChanged(_thisMonthRange());
                  close();
                },
              ),
              _PresetRow(
                label: 'All time',
                onTap: () {
                  widget.onChanged(null);
                  close();
                },
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.spacings.sm),
                child: Divider(height: 1, color: palette.border.primary),
              ),
              _PresetRow(
                label: 'Custom range...',
                onTap: () => _pickCustomRange(context, close),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PresetRow extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetRow({required this.label, required this.onTap});

  @override
  State<_PresetRow> createState() => _PresetRowState();
}

class _PresetRowState extends State<_PresetRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacings.md,
            vertical: theme.spacings.sm,
          ),
          color: _isHovered ? palette.background.surfaceMuted : null,
          child: Text(
            widget.label,
            style: theme.commonTextStyles.body2.copyWith(
              color: palette.text.primary,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create `index.dart`**

```dart
export 'date_range_button.dart';
```

- [ ] **Step 3: Add export to `ui_kit.dart`**

Add this line after the `multi_select` export added in Task 1:

```dart
export 'src/date_range_button/index.dart';
```

- [ ] **Step 4: Verify it compiles**

Run from `packages/worklog_studio_style_system/`: `fvm flutter analyze lib/ui_kit/src/date_range_button/`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add packages/worklog_studio_style_system/lib/ui_kit/src/date_range_button/ packages/worklog_studio_style_system/lib/ui_kit/ui_kit.dart
git commit -m "Add DateRangeButton ui-kit primitive"
```

---

### Task 3: Shared `TableToolbar` icon row

**Files:**
- Create: `packages/worklog_studio_style_system/lib/ui_kit/src/table/table_toolbar.dart`
- Modify: `packages/worklog_studio_style_system/lib/ui_kit/ui_kit.dart`

**Interfaces:**
- Consumes: `PrimaryButton` (`ui_kit/src/primary_button.dart`, params: `onTap`, `isDisabled`, `type: ButtonType`, `size: ButtonSize`, `leftIconWidget`), `context.theme`.
- Produces: `TableToolbar` widget with `isFilterExpanded: bool`, `onFilterTap: VoidCallback`, `activeFilterCount: int`. Renders Filter (active/wired), Sort (disabled), Settings (disabled) icon buttons in a row. Used by Task 7/8/9 page wiring, placed directly above each page's table.

- [ ] **Step 1: Create `table_toolbar.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class TableToolbar extends StatelessWidget {
  final bool isFilterExpanded;
  final VoidCallback onFilterTap;
  final int activeFilterCount;

  const TableToolbar({
    super.key,
    required this.isFilterExpanded,
    required this.onFilterTap,
    this.activeFilterCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Row(
      children: [
        _ToolbarIconButton(
          icon: Icons.filter_list,
          isActive: isFilterExpanded,
          badgeCount: activeFilterCount,
          onTap: onFilterTap,
        ),
        SizedBox(width: theme.spacings.sm),
        const _ToolbarIconButton(icon: Icons.sort, enabled: false),
        SizedBox(width: theme.spacings.sm),
        const _ToolbarIconButton(icon: Icons.settings_outlined, enabled: false),
      ],
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final bool isActive;
  final int badgeCount;
  final VoidCallback? onTap;

  const _ToolbarIconButton({
    required this.icon,
    this.enabled = true,
    this.isActive = false,
    this.badgeCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        PrimaryButton(
          onTap: enabled ? onTap : null,
          isDisabled: !enabled,
          type: isActive ? ButtonType.secondary : ButtonType.ghost,
          size: ButtonSize.sm,
          leftIconWidget: Icon(icon, size: 16),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 14),
              decoration: BoxDecoration(
                color: palette.accent.primary,
                borderRadius: theme.radiuses.pill.circular,
              ),
              child: Text(
                '$badgeCount',
                textAlign: TextAlign.center,
                style: theme.commonTextStyles.caption2.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: Add export to `ui_kit.dart`**

Add this line after `export 'src/table/ws_table.dart';`:

```dart
export 'src/table/table_toolbar.dart';
```

- [ ] **Step 3: Verify it compiles**

Run from `packages/worklog_studio_style_system/`: `fvm flutter analyze lib/ui_kit/src/table/table_toolbar.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add packages/worklog_studio_style_system/lib/ui_kit/src/table/table_toolbar.dart packages/worklog_studio_style_system/lib/ui_kit/ui_kit.dart
git commit -m "Add shared TableToolbar icon row"
```

---

### Task 4: `HistoryFilters` value class + `applyHistoryFilters` (TDD)

**Files:**
- Create: `apps/worklog_studio/lib/domain/history_filters.dart`
- Test: `apps/worklog_studio/test/core/history_filters_test.dart`

**Interfaces:**
- Consumes: `ResolvedTimeEntry` (`lib/domain/resolved_time_entry.dart` — fields/getters: `taskId: String?`, `projectId: String?`, `startAt: DateTime`).
- Produces: `HistoryFilters` (fields: `taskIds: Set<String>`, `projectIds: Set<String>`, `dateFrom: DateTime?`, `dateTo: DateTime?`; getters: `isActive: bool`, `activeCount: int`) and `applyHistoryFilters(List<ResolvedTimeEntry>, HistoryFilters) -> List<ResolvedTimeEntry>`. Consumed by Task 7 (History page wiring).

- [ ] **Step 1: Write the failing test**

Create `apps/worklog_studio/test/core/history_filters_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/history_filters.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';

ResolvedTimeEntry _entry({
  required String id,
  String? taskId,
  String? projectId,
  required DateTime startAt,
}) {
  return ResolvedTimeEntry(
    entry: TimeEntry(
      id: id,
      taskId: taskId,
      projectId: projectId,
      startAt: startAt,
      status: TimeEntryStatus.stopped,
    ),
    task: taskId != null
        ? Task(
            id: taskId,
            projectId: projectId ?? 'p0',
            title: 'Task $taskId',
            description: '',
            status: TaskStatus.open,
            createdAt: startAt,
          )
        : null,
    project: projectId != null
        ? Project(id: projectId, name: 'Project $projectId', description: '', createdAt: startAt)
        : null,
  );
}

void main() {
  group('HistoryFilters', () {
    test('isActive and activeCount are false/0 when nothing is set', () {
      const filters = HistoryFilters();
      expect(filters.isActive, isFalse);
      expect(filters.activeCount, 0);
    });

    test('activeCount sums each active dimension independently', () {
      final filters = HistoryFilters(
        taskIds: {'t1'},
        projectIds: {'p1'},
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 1, 31),
      );
      expect(filters.isActive, isTrue);
      expect(filters.activeCount, 3);
    });
  });

  group('applyHistoryFilters', () {
    final jan1 = DateTime(2026, 1, 1);
    final jan15 = DateTime(2026, 1, 15);
    final feb1 = DateTime(2026, 2, 1);

    final entries = [
      _entry(id: 'e1', taskId: 't1', projectId: 'p1', startAt: jan1),
      _entry(id: 'e2', taskId: 't2', projectId: 'p1', startAt: jan15),
      _entry(id: 'e3', taskId: 't1', projectId: 'p2', startAt: feb1),
      _entry(id: 'e4', startAt: jan15),
    ];

    test('returns all entries when no filters are set', () {
      final result = applyHistoryFilters(entries, const HistoryFilters());
      expect(result.length, 4);
    });

    test('filters by a single task id', () {
      final result = applyHistoryFilters(
        entries,
        const HistoryFilters(taskIds: {'t1'}),
      );
      expect(result.map((e) => e.id), ['e1', 'e3']);
    });

    test('filters by multiple task ids using OR logic', () {
      final result = applyHistoryFilters(
        entries,
        const HistoryFilters(taskIds: {'t1', 't2'}),
      );
      expect(result.map((e) => e.id), ['e1', 'e2', 'e3']);
    });

    test('filters by project id', () {
      final result = applyHistoryFilters(
        entries,
        const HistoryFilters(projectIds: {'p1'}),
      );
      expect(result.map((e) => e.id), ['e1', 'e2']);
    });

    test('filters by date range inclusive of both endpoints', () {
      final result = applyHistoryFilters(
        entries,
        HistoryFilters(dateFrom: jan1, dateTo: jan15),
      );
      expect(result.map((e) => e.id), ['e1', 'e2', 'e4']);
    });

    test('combines task, project, and date filters with AND logic', () {
      final result = applyHistoryFilters(
        entries,
        HistoryFilters(
          taskIds: {'t1'},
          projectIds: {'p1'},
          dateFrom: jan1,
          dateTo: jan1,
        ),
      );
      expect(result.map((e) => e.id), ['e1']);
    });

    test('entries with no task/project never match an active task or project filter', () {
      final result = applyHistoryFilters(
        entries,
        const HistoryFilters(taskIds: {'t1'}),
      );
      expect(result.any((e) => e.id == 'e4'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

From `apps/worklog_studio/`: `fvm flutter test test/core/history_filters_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:worklog_studio/domain/history_filters.dart'`.

- [ ] **Step 3: Write minimal implementation**

Create `apps/worklog_studio/lib/domain/history_filters.dart`:

```dart
import 'resolved_time_entry.dart';

class HistoryFilters {
  final Set<String> taskIds;
  final Set<String> projectIds;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const HistoryFilters({
    this.taskIds = const {},
    this.projectIds = const {},
    this.dateFrom,
    this.dateTo,
  });

  bool get isActive =>
      taskIds.isNotEmpty || projectIds.isNotEmpty || dateFrom != null;

  int get activeCount =>
      (taskIds.isNotEmpty ? 1 : 0) +
      (projectIds.isNotEmpty ? 1 : 0) +
      (dateFrom != null ? 1 : 0);
}

List<ResolvedTimeEntry> applyHistoryFilters(
  List<ResolvedTimeEntry> entries,
  HistoryFilters filters,
) {
  return entries.where((entry) {
    if (filters.taskIds.isNotEmpty && !filters.taskIds.contains(entry.taskId)) {
      return false;
    }
    if (filters.projectIds.isNotEmpty &&
        !filters.projectIds.contains(entry.projectId)) {
      return false;
    }
    if (filters.dateFrom != null && filters.dateTo != null) {
      final day = DateTime(
        entry.startAt.year,
        entry.startAt.month,
        entry.startAt.day,
      );
      final from = DateTime(
        filters.dateFrom!.year,
        filters.dateFrom!.month,
        filters.dateFrom!.day,
      );
      final to = DateTime(
        filters.dateTo!.year,
        filters.dateTo!.month,
        filters.dateTo!.day,
      );
      if (day.isBefore(from) || day.isAfter(to)) return false;
    }
    return true;
  }).toList();
}
```

- [ ] **Step 4: Run test to verify it passes**

From `apps/worklog_studio/`: `fvm flutter test test/core/history_filters_test.dart`
Expected: PASS, all tests green.

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/domain/history_filters.dart apps/worklog_studio/test/core/history_filters_test.dart
git commit -m "Add HistoryFilters and applyHistoryFilters with tests"
```

---

### Task 5: `TasksFilters` value class + `applyTasksFilters` (TDD)

**Files:**
- Create: `apps/worklog_studio/lib/domain/tasks_filters.dart`
- Test: `apps/worklog_studio/test/core/tasks_filters_test.dart`

**Interfaces:**
- Consumes: `ResolvedTask` (`lib/domain/resolved_task.dart` — getters: `projectId: String?`, `status: TaskStatus`, `createdAt: DateTime`), `TaskStatus` enum (`lib/domain/task.dart`: `open, done, archived`).
- Produces: `TasksFilters` (fields: `projectIds: Set<String>`, `statuses: Set<TaskStatus>`, `dateFrom: DateTime?`, `dateTo: DateTime?`; getters: `isActive`, `activeCount`) and `applyTasksFilters(List<ResolvedTask>, TasksFilters) -> List<ResolvedTask>`. Consumed by Task 8 (Tasks page wiring).

- [ ] **Step 1: Write the failing test**

Create `apps/worklog_studio/test/core/tasks_filters_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/resolved_task.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/tasks_filters.dart';

ResolvedTask _task({
  required String id,
  required String projectId,
  required TaskStatus status,
  required DateTime createdAt,
}) {
  return ResolvedTask(
    task: Task(
      id: id,
      projectId: projectId,
      title: 'Task $id',
      description: '',
      status: status,
      createdAt: createdAt,
    ),
    project: Project(
      id: projectId,
      name: 'Project $projectId',
      description: '',
      createdAt: createdAt,
    ),
  );
}

void main() {
  group('TasksFilters', () {
    test('isActive and activeCount are false/0 when nothing is set', () {
      const filters = TasksFilters();
      expect(filters.isActive, isFalse);
      expect(filters.activeCount, 0);
    });

    test('activeCount sums each active dimension independently', () {
      final filters = TasksFilters(
        projectIds: {'p1'},
        statuses: {TaskStatus.open},
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 1, 31),
      );
      expect(filters.activeCount, 3);
    });
  });

  group('applyTasksFilters', () {
    final jan1 = DateTime(2026, 1, 1);
    final jan15 = DateTime(2026, 1, 15);
    final feb1 = DateTime(2026, 2, 1);

    final tasks = [
      _task(id: 't1', projectId: 'p1', status: TaskStatus.open, createdAt: jan1),
      _task(id: 't2', projectId: 'p1', status: TaskStatus.done, createdAt: jan15),
      _task(id: 't3', projectId: 'p2', status: TaskStatus.open, createdAt: feb1),
    ];

    test('returns all tasks when no filters are set', () {
      final result = applyTasksFilters(tasks, const TasksFilters());
      expect(result.length, 3);
    });

    test('filters by project id', () {
      final result = applyTasksFilters(
        tasks,
        const TasksFilters(projectIds: {'p1'}),
      );
      expect(result.map((t) => t.id), ['t1', 't2']);
    });

    test('filters by multiple statuses using OR logic', () {
      final result = applyTasksFilters(
        tasks,
        const TasksFilters(statuses: {TaskStatus.open}),
      );
      expect(result.map((t) => t.id), ['t1', 't3']);
    });

    test('filters by date range inclusive of both endpoints', () {
      final result = applyTasksFilters(
        tasks,
        TasksFilters(dateFrom: jan1, dateTo: jan15),
      );
      expect(result.map((t) => t.id), ['t1', 't2']);
    });

    test('combines project, status, and date filters with AND logic', () {
      final result = applyTasksFilters(
        tasks,
        TasksFilters(
          projectIds: {'p1'},
          statuses: {TaskStatus.open},
          dateFrom: jan1,
          dateTo: jan1,
        ),
      );
      expect(result.map((t) => t.id), ['t1']);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

From `apps/worklog_studio/`: `fvm flutter test test/core/tasks_filters_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:worklog_studio/domain/tasks_filters.dart'`.

- [ ] **Step 3: Write minimal implementation**

Create `apps/worklog_studio/lib/domain/tasks_filters.dart`:

```dart
import 'resolved_task.dart';
import 'task.dart';

class TasksFilters {
  final Set<String> projectIds;
  final Set<TaskStatus> statuses;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const TasksFilters({
    this.projectIds = const {},
    this.statuses = const {},
    this.dateFrom,
    this.dateTo,
  });

  bool get isActive =>
      projectIds.isNotEmpty || statuses.isNotEmpty || dateFrom != null;

  int get activeCount =>
      (projectIds.isNotEmpty ? 1 : 0) +
      (statuses.isNotEmpty ? 1 : 0) +
      (dateFrom != null ? 1 : 0);
}

List<ResolvedTask> applyTasksFilters(
  List<ResolvedTask> tasks,
  TasksFilters filters,
) {
  return tasks.where((task) {
    if (filters.projectIds.isNotEmpty &&
        !filters.projectIds.contains(task.projectId)) {
      return false;
    }
    if (filters.statuses.isNotEmpty && !filters.statuses.contains(task.status)) {
      return false;
    }
    if (filters.dateFrom != null && filters.dateTo != null) {
      final day = DateTime(
        task.createdAt.year,
        task.createdAt.month,
        task.createdAt.day,
      );
      final from = DateTime(
        filters.dateFrom!.year,
        filters.dateFrom!.month,
        filters.dateFrom!.day,
      );
      final to = DateTime(
        filters.dateTo!.year,
        filters.dateTo!.month,
        filters.dateTo!.day,
      );
      if (day.isBefore(from) || day.isAfter(to)) return false;
    }
    return true;
  }).toList();
}
```

- [ ] **Step 4: Run test to verify it passes**

From `apps/worklog_studio/`: `fvm flutter test test/core/tasks_filters_test.dart`
Expected: PASS, all tests green.

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/domain/tasks_filters.dart apps/worklog_studio/test/core/tasks_filters_test.dart
git commit -m "Add TasksFilters and applyTasksFilters with tests"
```

---

### Task 6: `ProjectsFilters` value class + `applyProjectsFilters` (TDD)

**Files:**
- Create: `apps/worklog_studio/lib/domain/projects_filters.dart`
- Test: `apps/worklog_studio/test/core/projects_filters_test.dart`

**Interfaces:**
- Consumes: `ResolvedProject` (`lib/domain/resolved_project.dart` — getters: `status: ProjectStatus`, `createdAt: DateTime`), `ProjectStatus` enum (`lib/domain/project.dart`: `open, done, archived`).
- Produces: `ProjectsFilters` (fields: `statuses: Set<ProjectStatus>`, `dateFrom: DateTime?`, `dateTo: DateTime?`; getters: `isActive`, `activeCount`) and `applyProjectsFilters(List<ResolvedProject>, ProjectsFilters) -> List<ResolvedProject>`. Consumed by Task 9 (Projects page wiring).

- [ ] **Step 1: Write the failing test**

Create `apps/worklog_studio/test/core/projects_filters_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/projects_filters.dart';
import 'package:worklog_studio/domain/resolved_project.dart';

ResolvedProject _project({
  required String id,
  required ProjectStatus status,
  required DateTime createdAt,
}) {
  return ResolvedProject(
    project: Project(
      id: id,
      name: 'Project $id',
      description: '',
      createdAt: createdAt,
      status: status,
    ),
  );
}

void main() {
  group('ProjectsFilters', () {
    test('isActive and activeCount are false/0 when nothing is set', () {
      const filters = ProjectsFilters();
      expect(filters.isActive, isFalse);
      expect(filters.activeCount, 0);
    });

    test('activeCount sums each active dimension independently', () {
      final filters = ProjectsFilters(
        statuses: {ProjectStatus.open},
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 1, 31),
      );
      expect(filters.activeCount, 2);
    });
  });

  group('applyProjectsFilters', () {
    final jan1 = DateTime(2026, 1, 1);
    final jan15 = DateTime(2026, 1, 15);
    final feb1 = DateTime(2026, 2, 1);

    final projects = [
      _project(id: 'p1', status: ProjectStatus.open, createdAt: jan1),
      _project(id: 'p2', status: ProjectStatus.done, createdAt: jan15),
      _project(id: 'p3', status: ProjectStatus.open, createdAt: feb1),
    ];

    test('returns all projects when no filters are set', () {
      final result = applyProjectsFilters(projects, const ProjectsFilters());
      expect(result.length, 3);
    });

    test('filters by multiple statuses using OR logic', () {
      final result = applyProjectsFilters(
        projects,
        const ProjectsFilters(statuses: {ProjectStatus.open}),
      );
      expect(result.map((p) => p.id), ['p1', 'p3']);
    });

    test('filters by date range inclusive of both endpoints', () {
      final result = applyProjectsFilters(
        projects,
        ProjectsFilters(dateFrom: jan1, dateTo: jan15),
      );
      expect(result.map((p) => p.id), ['p1', 'p2']);
    });

    test('combines status and date filters with AND logic', () {
      final result = applyProjectsFilters(
        projects,
        ProjectsFilters(
          statuses: {ProjectStatus.open},
          dateFrom: jan1,
          dateTo: jan1,
        ),
      );
      expect(result.map((p) => p.id), ['p1']);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

From `apps/worklog_studio/`: `fvm flutter test test/core/projects_filters_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:worklog_studio/domain/projects_filters.dart'`.

- [ ] **Step 3: Write minimal implementation**

Create `apps/worklog_studio/lib/domain/projects_filters.dart`:

```dart
import 'project.dart';
import 'resolved_project.dart';

class ProjectsFilters {
  final Set<ProjectStatus> statuses;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const ProjectsFilters({
    this.statuses = const {},
    this.dateFrom,
    this.dateTo,
  });

  bool get isActive => statuses.isNotEmpty || dateFrom != null;

  int get activeCount =>
      (statuses.isNotEmpty ? 1 : 0) + (dateFrom != null ? 1 : 0);
}

List<ResolvedProject> applyProjectsFilters(
  List<ResolvedProject> projects,
  ProjectsFilters filters,
) {
  return projects.where((project) {
    if (filters.statuses.isNotEmpty &&
        !filters.statuses.contains(project.status)) {
      return false;
    }
    if (filters.dateFrom != null && filters.dateTo != null) {
      final day = DateTime(
        project.createdAt.year,
        project.createdAt.month,
        project.createdAt.day,
      );
      final from = DateTime(
        filters.dateFrom!.year,
        filters.dateFrom!.month,
        filters.dateFrom!.day,
      );
      final to = DateTime(
        filters.dateTo!.year,
        filters.dateTo!.month,
        filters.dateTo!.day,
      );
      if (day.isBefore(from) || day.isAfter(to)) return false;
    }
    return true;
  }).toList();
}
```

- [ ] **Step 4: Run test to verify it passes**

From `apps/worklog_studio/`: `fvm flutter test test/core/projects_filters_test.dart`
Expected: PASS, all tests green.

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/domain/projects_filters.dart apps/worklog_studio/test/core/projects_filters_test.dart
git commit -m "Add ProjectsFilters and applyProjectsFilters with tests"
```

---

### Task 7: Wire filter bar into History page

**Files:**
- Create: `apps/worklog_studio/lib/feature/history/presentation/components/history_filter_bar.dart`
- Create: `packages/worklog_studio_style_system/lib/ui_kit/src/table/clearable_filter_pill.dart`
- Modify: `apps/worklog_studio/lib/feature/history/presentation/history_page.dart`
- Modify: `packages/worklog_studio_style_system/lib/ui_kit/ui_kit.dart`

**Interfaces:**
- Consumes: `TableToolbar`, `MultiSelect<String>`, `DateRangeButton`, `SelectOption<String>` (from ui-kit), `HistoryFilters`/`applyHistoryFilters` (Task 4), `EntityResolver.getResolvedTasks()`/`getResolvedProjects()` (`lib/state/entity_resolver.dart`) for building Task/Project option lists.
- Produces: `HistoryFilterBar` stateless widget with `filters: HistoryFilters`, `onChanged: ValueChanged<HistoryFilters>`, `taskOptions: List<SelectOption<String>>`, `projectOptions: List<SelectOption<String>>`. Used only inside `history_page.dart`. Also produces `ClearableFilterPill` (ui-kit, fields: `child: Widget`, `isActive: bool`, `onClear: VoidCallback`) — reused unchanged by Task 8 and Task 9, which must NOT recreate it.

- [ ] **Step 1: Create `history_filter_bar.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/history_filters.dart';

class HistoryFilterBar extends StatelessWidget {
  final HistoryFilters filters;
  final ValueChanged<HistoryFilters> onChanged;
  final List<SelectOption<String>> taskOptions;
  final List<SelectOption<String>> projectOptions;

  const HistoryFilterBar({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.taskOptions,
    required this.projectOptions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Row(
      children: [
        ClearableFilterPill(
          isActive: filters.taskIds.isNotEmpty,
          onClear: () => onChanged(
            HistoryFilters(
              taskIds: const {},
              projectIds: filters.projectIds,
              dateFrom: filters.dateFrom,
              dateTo: filters.dateTo,
            ),
          ),
          child: MultiSelect<String>(
            value: filters.taskIds.toList(),
            onChanged: (ids) => onChanged(
              HistoryFilters(
                taskIds: ids.toSet(),
                projectIds: filters.projectIds,
                dateFrom: filters.dateFrom,
                dateTo: filters.dateTo,
              ),
            ),
            options: taskOptions,
            placeholder: 'Task',
            searchable: true,
          ),
        ),
        SizedBox(width: theme.spacings.sm),
        ClearableFilterPill(
          isActive: filters.projectIds.isNotEmpty,
          onClear: () => onChanged(
            HistoryFilters(
              taskIds: filters.taskIds,
              projectIds: const {},
              dateFrom: filters.dateFrom,
              dateTo: filters.dateTo,
            ),
          ),
          child: MultiSelect<String>(
            value: filters.projectIds.toList(),
            onChanged: (ids) => onChanged(
              HistoryFilters(
                taskIds: filters.taskIds,
                projectIds: ids.toSet(),
                dateFrom: filters.dateFrom,
                dateTo: filters.dateTo,
              ),
            ),
            options: projectOptions,
            placeholder: 'Project',
            searchable: true,
          ),
        ),
        SizedBox(width: theme.spacings.sm),
        ClearableFilterPill(
          isActive: filters.dateFrom != null,
          onClear: () => onChanged(
            HistoryFilters(taskIds: filters.taskIds, projectIds: filters.projectIds),
          ),
          child: DateRangeButton(
            value: filters.dateFrom != null
                ? DateTimeRange(start: filters.dateFrom!, end: filters.dateTo!)
                : null,
            onChanged: (range) => onChanged(
              HistoryFilters(
                taskIds: filters.taskIds,
                projectIds: filters.projectIds,
                dateFrom: range?.start,
                dateTo: range?.end,
              ),
            ),
            placeholder: 'Date',
          ),
        ),
        if (filters.isActive) ...[
          SizedBox(width: theme.spacings.sm),
          TextButton(
            onPressed: () => onChanged(const HistoryFilters()),
            child: Text(
              'Reset all',
              style: theme.commonTextStyles.caption.copyWith(
                color: theme.colorsPalette.text.secondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
```

`ClearableFilterPill` is a small shared widget added to the ui-kit in this same task (Step 1b below) — it wraps any pill-shaped child and overlays a small "×" in its top-right corner when `isActive` is true, calling `onClear` without opening the wrapped popover. All three filter bars (History, Tasks, Projects) use it for every pill, so it lives in the ui-kit rather than being duplicated three times.

- [ ] **Step 1b: Add `ClearableFilterPill` to the ui-kit**

Create `packages/worklog_studio_style_system/lib/ui_kit/src/table/clearable_filter_pill.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class ClearableFilterPill extends StatelessWidget {
  final Widget child;
  final bool isActive;
  final VoidCallback onClear;

  const ClearableFilterPill({
    super.key,
    required this.child,
    required this.isActive,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return child;

    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onClear,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: palette.text.secondary,
                shape: BoxShape.circle,
                border: Border.all(color: palette.background.surface, width: 1.5),
              ),
              child: const Icon(Icons.close, size: 10, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
```

Add this export to `ui_kit.dart` next to `export 'src/table/table_toolbar.dart';`:

```dart
export 'src/table/clearable_filter_pill.dart';
```

- [ ] **Step 2: Wire it into `history_page.dart`**

In `apps/worklog_studio/lib/feature/history/presentation/history_page.dart`, add imports after the existing `package:worklog_studio_style_system/worklog_studio_style_system.dart` import:

```dart
import 'package:worklog_studio/domain/history_filters.dart';
import 'components/history_filter_bar.dart';
```

In `_HistoryScreenState` (around line 36-39, alongside the existing `_drawerState`/`_viewMode` fields), add:

```dart
  HistoryFilters _filters = const HistoryFilters();
  bool _isFilterExpanded = false;
```

In `TimeEntryList` (the `StatelessWidget`, starting at line 145), add two new required constructor parameters and fields, alongside the existing `viewMode`/`onViewModeChanged`:

```dart
  final HistoryFilters filters;
  final ValueChanged<HistoryFilters> onFiltersChanged;
  final bool isFilterExpanded;
  final VoidCallback onFilterExpandedToggle;
```

and in its constructor:

```dart
    required this.filters,
    required this.onFiltersChanged,
    required this.isFilterExpanded,
    required this.onFilterExpandedToggle,
```

In `_HistoryScreenState.build` (around line 120-128), pass the new values through to `TimeEntryList`:

```dart
              filters: _filters,
              onFiltersChanged: (f) => setState(() => _filters = f),
              isFilterExpanded: _isFilterExpanded,
              onFilterExpandedToggle: () =>
                  setState(() => _isFilterExpanded = !_isFilterExpanded),
```

In `TimeEntryList.build` (around line 166-177), apply the filters before sorting/grouping — replace:

```dart
    // Sort entries: latest first
    final sortedEntries = List<ResolvedTimeEntry>.from(entries)
```

with:

```dart
    final filteredEntries = applyHistoryFilters(entries, filters);

    // Sort entries: latest first
    final sortedEntries = List<ResolvedTimeEntry>.from(filteredEntries)
```

Add the missing import for `applyHistoryFilters` next to the `history_filters.dart` import added above (same file, already covers it since both live in `history_filters.dart`).

After the KPI strip `Builder` widget closes (after line 294, `SizedBox(height: theme.spacings.x2l)` at line 295), insert the new toolbar row and conditional filter-pill row:

```dart
          SizedBox(height: theme.spacings.lg),
          TableToolbar(
            isFilterExpanded: isFilterExpanded,
            onFilterTap: onFilterExpandedToggle,
            activeFilterCount: filters.activeCount,
          ),
          if (isFilterExpanded) ...[
            SizedBox(height: theme.spacings.sm),
            Builder(
              builder: (context) {
                final resolver = context.watch<EntityResolver>();
                final taskOptions = resolver
                    .getResolvedTasks()
                    .map((t) => SelectOption(value: t.id, label: t.title))
                    .toList();
                final projectOptions = resolver
                    .getResolvedProjects()
                    .map((p) => SelectOption(value: p.id, label: p.name))
                    .toList();
                return HistoryFilterBar(
                  filters: filters,
                  onChanged: onFiltersChanged,
                  taskOptions: taskOptions,
                  projectOptions: projectOptions,
                );
              },
            ),
          ],
          SizedBox(height: theme.spacings.x2l),
```

This replaces the existing `SizedBox(height: theme.spacings.x2l)` that previously sat between the KPI strip and the scrollable table area — the new block ends with the same spacing so the table's position below is preserved.

`EntityResolver` is already imported in this file (line 8); `SelectOption` and `TableToolbar` come from the `worklog_studio_style_system` barrel already imported at line 5.

- [ ] **Step 3: Analyze**

From `apps/worklog_studio/`: `fvm flutter analyze lib/feature/history/`
From `packages/worklog_studio_style_system/`: `fvm flutter analyze lib/ui_kit/src/table/clearable_filter_pill.dart`
Expected: No errors in either.

- [ ] **Step 4: Run full test suite**

From `apps/worklog_studio/`: `fvm flutter test test/core/ test/feature/ --reporter expanded`
Expected: All existing tests still pass (no behavior change to non-History logic).

- [ ] **Step 5: Manual verification**

Run the app (`fvm flutter run -d windows` from `apps/worklog_studio/`), open the History page, confirm:
- A toolbar row with Filter/Sort/Settings icons appears directly above the table, below the KPI strip.
- Clicking Filter toggles the Task/Project/Date pill row.
- Selecting tasks/projects in the multi-selects filters the table and the cards view identically.
- Selecting a date range filters by day; "All time" clears it.
- The Filter icon shows a count badge matching active filters even when collapsed.
- "Reset all" clears every filter.
- Sort and Settings icons are visibly disabled and do nothing.

- [ ] **Step 6: Commit**

```bash
git add apps/worklog_studio/lib/feature/history/ packages/worklog_studio_style_system/lib/ui_kit/src/table/clearable_filter_pill.dart packages/worklog_studio_style_system/lib/ui_kit/ui_kit.dart
git commit -m "Wire filter toolbar into History page"
```

---

### Task 8: Wire filter bar into Tasks page

**Files:**
- Create: `apps/worklog_studio/lib/feature/tasks/presentation/components/tasks_filter_bar.dart`
- Modify: `apps/worklog_studio/lib/feature/tasks/presentation/tasks_page.dart`

**Interfaces:**
- Consumes: `TableToolbar`, `MultiSelect<String>`, `MultiSelect<TaskStatus>`, `DateRangeButton`, `SelectOption<T>` (ui-kit), `TasksFilters`/`applyTasksFilters` (Task 5), `EntityResolver.getResolvedProjects()`.
- Produces: `TasksFilterBar` stateless widget with `filters: TasksFilters`, `onChanged: ValueChanged<TasksFilters>`, `projectOptions: List<SelectOption<String>>`. Used only inside `tasks_page.dart`.

- [ ] **Step 1: Create `tasks_filter_bar.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/tasks_filters.dart';

class TasksFilterBar extends StatelessWidget {
  final TasksFilters filters;
  final ValueChanged<TasksFilters> onChanged;
  final List<SelectOption<String>> projectOptions;

  const TasksFilterBar({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.projectOptions,
  });

  static const _statusOptions = [
    SelectOption(value: TaskStatus.open, label: 'Open'),
    SelectOption(value: TaskStatus.done, label: 'Done'),
    SelectOption(value: TaskStatus.archived, label: 'Archived'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Row(
      children: [
        ClearableFilterPill(
          isActive: filters.projectIds.isNotEmpty,
          onClear: () => onChanged(
            TasksFilters(
              projectIds: const {},
              statuses: filters.statuses,
              dateFrom: filters.dateFrom,
              dateTo: filters.dateTo,
            ),
          ),
          child: MultiSelect<String>(
            value: filters.projectIds.toList(),
            onChanged: (ids) => onChanged(
              TasksFilters(
                projectIds: ids.toSet(),
                statuses: filters.statuses,
                dateFrom: filters.dateFrom,
                dateTo: filters.dateTo,
              ),
            ),
            options: projectOptions,
            placeholder: 'Project',
            searchable: true,
          ),
        ),
        SizedBox(width: theme.spacings.sm),
        ClearableFilterPill(
          isActive: filters.statuses.isNotEmpty,
          onClear: () => onChanged(
            TasksFilters(
              projectIds: filters.projectIds,
              statuses: const {},
              dateFrom: filters.dateFrom,
              dateTo: filters.dateTo,
            ),
          ),
          child: MultiSelect<TaskStatus>(
            value: filters.statuses.toList(),
            onChanged: (statuses) => onChanged(
              TasksFilters(
                projectIds: filters.projectIds,
                statuses: statuses.toSet(),
                dateFrom: filters.dateFrom,
                dateTo: filters.dateTo,
              ),
            ),
            options: _statusOptions,
            placeholder: 'Status',
          ),
        ),
        SizedBox(width: theme.spacings.sm),
        ClearableFilterPill(
          isActive: filters.dateFrom != null,
          onClear: () => onChanged(
            TasksFilters(projectIds: filters.projectIds, statuses: filters.statuses),
          ),
          child: DateRangeButton(
            value: filters.dateFrom != null
                ? DateTimeRange(start: filters.dateFrom!, end: filters.dateTo!)
                : null,
            onChanged: (range) => onChanged(
              TasksFilters(
                projectIds: filters.projectIds,
                statuses: filters.statuses,
                dateFrom: range?.start,
                dateTo: range?.end,
              ),
            ),
            placeholder: 'Date',
          ),
        ),
        if (filters.isActive) ...[
          SizedBox(width: theme.spacings.sm),
          TextButton(
            onPressed: () => onChanged(const TasksFilters()),
            child: Text(
              'Reset all',
              style: theme.commonTextStyles.caption.copyWith(
                color: theme.colorsPalette.text.secondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
```

`ClearableFilterPill` was already added to the ui-kit in Task 7 — do not recreate it here, just import the style-system barrel as usual.

- [ ] **Step 2: Wire it into `tasks_page.dart`**

Add imports after the existing style-system import:

```dart
import 'package:worklog_studio/domain/tasks_filters.dart';
import 'components/tasks_filter_bar.dart';
```

In `_TasksScreenState` (alongside `_drawerState`/`_viewMode`), add:

```dart
  TasksFilters _filters = const TasksFilters();
  bool _isFilterExpanded = false;
```

In `TaskList` (the `StatelessWidget`), add constructor params/fields alongside `viewMode`/`onViewModeChanged`:

```dart
  final TasksFilters filters;
  final ValueChanged<TasksFilters> onFiltersChanged;
  final bool isFilterExpanded;
  final VoidCallback onFilterExpandedToggle;
```

and in its constructor:

```dart
    required this.filters,
    required this.onFiltersChanged,
    required this.isFilterExpanded,
    required this.onFilterExpandedToggle,
```

In `_TasksScreenState.build`, pass these through to `TaskList`:

```dart
            filters: _filters,
            onFiltersChanged: (f) => setState(() => _filters = f),
            isFilterExpanded: _isFilterExpanded,
            onFilterExpandedToggle: () =>
                setState(() => _isFilterExpanded = !_isFilterExpanded),
```

In `TaskList.build`, replace the `viewMode == TaskViewMode.table ? WsTable<ResolvedTask>(...) : Column(...)` block's surrounding structure: filter `tasks` before branching, and insert the toolbar row above it. Replace:

```dart
          SizedBox(height: theme.spacings.x2l),
          Expanded(
            child: SingleChildScrollView(
              child: viewMode == TaskViewMode.table
```

with:

```dart
          SizedBox(height: theme.spacings.lg),
          TableToolbar(
            isFilterExpanded: isFilterExpanded,
            onFilterTap: onFilterExpandedToggle,
            activeFilterCount: filters.activeCount,
          ),
          if (isFilterExpanded) ...[
            SizedBox(height: theme.spacings.sm),
            Builder(
              builder: (context) {
                final resolver = context.watch<EntityResolver>();
                final projectOptions = resolver
                    .getResolvedProjects()
                    .map((p) => SelectOption(value: p.id, label: p.name))
                    .toList();
                return TasksFilterBar(
                  filters: filters,
                  onChanged: onFiltersChanged,
                  projectOptions: projectOptions,
                );
              },
            ),
          ],
          SizedBox(height: theme.spacings.x2l),
          Expanded(
            child: SingleChildScrollView(
              child: () {
                final filteredTasks = applyTasksFilters(tasks, filters);
                return filteredTasks.isEmpty
                    ? const SizedBox.shrink()
                    : viewMode == TaskViewMode.table
```

Then close the new closure: the existing ternary branches (`WsTable<ResolvedTask>(...)` / `Column(...)`) must reference `filteredTasks` instead of `tasks` in their `data:`/`children:` source, and the whole expression must be wrapped to return from the `() { ... }()` closure. Concretely, the existing block:

```dart
                  ? WsTable<ResolvedTask>(
                      data: tasks,
                      selectedItem: tasks.firstWhereOrNull(
```

becomes:

```dart
                    ? WsTable<ResolvedTask>(
                      data: filteredTasks,
                      selectedItem: filteredTasks.firstWhereOrNull(
```

and:

```dart
                  : Column(
                      spacing: theme.spacings.md,
                      children: tasks.map((task) {
```

becomes:

```dart
                    : Column(
                      spacing: theme.spacings.md,
                      children: filteredTasks.map((task) {
```

and the closure is closed and invoked right after the existing `),` that ends the `Column(...)`/ternary, followed by `}()`:

```dart
                    ),
              }(),
            ),
          ),
```

`EntityResolver` and `SelectOption` are already available via existing imports (`entity_resolver.dart` is imported in `tasks_page.dart`; `SelectOption`/`TableToolbar` come from the `worklog_studio_style_system` barrel already imported).

- [ ] **Step 3: Analyze**

From `apps/worklog_studio/`: `fvm flutter analyze lib/feature/tasks/`
Expected: No errors. Pay particular attention to the closure indentation/braces introduced in Step 2 — this is the trickiest edit in the plan; if `flutter analyze` reports a syntax error, re-read the surrounding `TaskList.build` method in full before re-editing, rather than patching blindly.

- [ ] **Step 4: Run full test suite**

From `apps/worklog_studio/`: `fvm flutter test test/core/ test/feature/ --reporter expanded`
Expected: All existing tests still pass.

- [ ] **Step 5: Manual verification**

Run the app, open the Tasks page, confirm: toolbar row above the table, Project/Status/Date pills filter both table and cards views identically, badge count and Reset all work, Sort/Settings stay disabled.

- [ ] **Step 6: Commit**

```bash
git add apps/worklog_studio/lib/feature/tasks/
git commit -m "Wire filter toolbar into Tasks page"
```

---

### Task 9: Wire filter bar into Projects page

**Files:**
- Create: `apps/worklog_studio/lib/feature/projects/presentation/components/projects_filter_bar.dart`
- Modify: `apps/worklog_studio/lib/feature/projects/presentation/projects_page.dart`

**Interfaces:**
- Consumes: `TableToolbar`, `MultiSelect<ProjectStatus>`, `DateRangeButton`, `SelectOption<ProjectStatus>` (ui-kit), `ProjectsFilters`/`applyProjectsFilters` (Task 6).
- Produces: `ProjectsFilterBar` stateless widget with `filters: ProjectsFilters`, `onChanged: ValueChanged<ProjectsFilters>`. Used only inside `projects_page.dart`.

- [ ] **Step 1: Create `projects_filter_bar.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/projects_filters.dart';

class ProjectsFilterBar extends StatelessWidget {
  final ProjectsFilters filters;
  final ValueChanged<ProjectsFilters> onChanged;

  const ProjectsFilterBar({
    super.key,
    required this.filters,
    required this.onChanged,
  });

  static const _statusOptions = [
    SelectOption(value: ProjectStatus.open, label: 'Open'),
    SelectOption(value: ProjectStatus.done, label: 'Done'),
    SelectOption(value: ProjectStatus.archived, label: 'Archived'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Row(
      children: [
        ClearableFilterPill(
          isActive: filters.statuses.isNotEmpty,
          onClear: () => onChanged(
            ProjectsFilters(
              statuses: const {},
              dateFrom: filters.dateFrom,
              dateTo: filters.dateTo,
            ),
          ),
          child: MultiSelect<ProjectStatus>(
            value: filters.statuses.toList(),
            onChanged: (statuses) => onChanged(
              ProjectsFilters(
                statuses: statuses.toSet(),
                dateFrom: filters.dateFrom,
                dateTo: filters.dateTo,
              ),
            ),
            options: _statusOptions,
            placeholder: 'Status',
          ),
        ),
        SizedBox(width: theme.spacings.sm),
        ClearableFilterPill(
          isActive: filters.dateFrom != null,
          onClear: () => onChanged(ProjectsFilters(statuses: filters.statuses)),
          child: DateRangeButton(
            value: filters.dateFrom != null
                ? DateTimeRange(start: filters.dateFrom!, end: filters.dateTo!)
                : null,
            onChanged: (range) => onChanged(
              ProjectsFilters(
                statuses: filters.statuses,
                dateFrom: range?.start,
                dateTo: range?.end,
              ),
            ),
            placeholder: 'Date',
          ),
        ),
        if (filters.isActive) ...[
          SizedBox(width: theme.spacings.sm),
          TextButton(
            onPressed: () => onChanged(const ProjectsFilters()),
            child: Text(
              'Reset all',
              style: theme.commonTextStyles.caption.copyWith(
                color: theme.colorsPalette.text.secondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
```

`ClearableFilterPill` was already added to the ui-kit in Task 7 — do not recreate it here.

- [ ] **Step 2: Wire it into `projects_page.dart`**

Add imports after the existing style-system import:

```dart
import 'package:worklog_studio/domain/projects_filters.dart';
import 'components/projects_filter_bar.dart';
```

In `_ProjectsScreenState`, add:

```dart
  ProjectsFilters _filters = const ProjectsFilters();
  bool _isFilterExpanded = false;
```

In `ProjectList`, add constructor params/fields alongside `viewMode`/`onViewModeChanged`:

```dart
  final ProjectsFilters filters;
  final ValueChanged<ProjectsFilters> onFiltersChanged;
  final bool isFilterExpanded;
  final VoidCallback onFilterExpandedToggle;
```

and in its constructor:

```dart
    required this.filters,
    required this.onFiltersChanged,
    required this.isFilterExpanded,
    required this.onFilterExpandedToggle,
```

In `_ProjectsScreenState.build`, pass these through to `ProjectList`:

```dart
            filters: _filters,
            onFiltersChanged: (f) => setState(() => _filters = f),
            isFilterExpanded: _isFilterExpanded,
            onFilterExpandedToggle: () =>
                setState(() => _isFilterExpanded = !_isFilterExpanded),
```

In `ProjectList.build`, apply the same pattern as Task 8's Tasks page: replace

```dart
          SizedBox(height: theme.spacings.x2l),
          Expanded(
            child: SingleChildScrollView(
              child: viewMode == ProjectViewMode.table
```

with:

```dart
          SizedBox(height: theme.spacings.lg),
          TableToolbar(
            isFilterExpanded: isFilterExpanded,
            onFilterTap: onFilterExpandedToggle,
            activeFilterCount: filters.activeCount,
          ),
          if (isFilterExpanded) ...[
            SizedBox(height: theme.spacings.sm),
            ProjectsFilterBar(filters: filters, onChanged: onFiltersChanged),
          ],
          SizedBox(height: theme.spacings.x2l),
          Expanded(
            child: SingleChildScrollView(
              child: () {
                final filteredProjects = applyProjectsFilters(projects, filters);
                return filteredProjects.isEmpty
                    ? const SizedBox.shrink()
                    : viewMode == ProjectViewMode.table
```

and update the two branches to use `filteredProjects` instead of `projects` (`data: filteredProjects`, `selectedItem: filteredProjects.firstWhereOrNull(...)`, `children: filteredProjects.map((project) {...})`), closing with `}()` exactly as described in Task 8 Step 2 for the Tasks page (same closure pattern, same care needed with `flutter analyze` afterward).

Note: Projects has no Task filter, so unlike Task 7/8 there's no need to watch `EntityResolver` here — `ProjectsFilterBar` only needs `filters`/`onChanged`.

- [ ] **Step 3: Analyze**

From `apps/worklog_studio/`: `fvm flutter analyze lib/feature/projects/`
Expected: No errors.

- [ ] **Step 4: Run full test suite**

From `apps/worklog_studio/`: `fvm flutter test test/core/ test/feature/ --reporter expanded`
Expected: All tests pass, including the three new filter-predicate test files from Tasks 4-6.

- [ ] **Step 5: Manual verification**

Run the app, open the Projects page, confirm: toolbar row above the table, Status/Date pills filter both table and cards views identically, badge count and Reset all work, Sort/Settings stay disabled.

- [ ] **Step 6: Commit**

```bash
git add apps/worklog_studio/lib/feature/projects/
git commit -m "Wire filter toolbar into Projects page"
```

---

## Final check

After Task 9, run the full suite once more from `apps/worklog_studio/`:

```bash
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all green. Then do one more manual pass across History, Tasks, and Projects pages confirming the toolbar row sits directly above the table on every page (not merged into the title row), and that toggling cards/table view preserves the active filter set.
