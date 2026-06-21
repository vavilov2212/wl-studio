# Select: navigable items Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let `Select` option rows show a hover effect and an optional small action icon that navigates to the underlying entity (opening its existing edit drawer) without changing the current selection, and wire that up for the project/task selects in the app shell's tracking panel and the drawers that nest project/task selects.

**Architecture:** The reusable visual/interaction behavior (hover tint, action icon, popup `minWidth`) lives entirely in the `worklog_studio_style_system` package on `Select`/`SelectOption`/`SelectContent`/`Combobox`/`PopoverPrimitive`. Cross-page navigation reuses the app's existing dashboard-card pattern (`AppShell._openTask`/`_openHistoryEntry`: switch tab, pass an `initialSelectedXId`, the target screen opens its drawer and scrolls the row into view) via a new `AppNavigationController` that any widget can reach through `Provider`, regardless of nesting depth. `TaskDrawer`/`ProjectDrawer`/`TimeEntryDrawer` keep their current local state and inline `Row` layout — untouched.

**Tech Stack:** Flutter, `provider` (already a dependency), `flutter_test`.

## Global Constraints

- Always invoke Flutter/Dart through `fvm` (`fvm flutter test ...`), never bare `flutter`/`dart`.
- Run tests from the package that owns them: `apps\worklog_studio` for app tests, `packages\worklog_studio_style_system` for style-system tests.
- UI-only widget changes are exempt from mandatory unit tests; logic extracted from widgets (e.g. `AppNavigationController`) must have unit tests — per `apps\worklog_studio\CLAUDE.md`.
- No hardcoded colors/paddings in `apps\` — use `context.theme` tokens (`spacings`, `radiuses`, `colorsPalette`) everywhere, including in the style-system package itself.
- New hardcoded user-facing strings need a `// TODO: l10n` comment (per the `l10n-asset-stubber` project skill).
- Never add a `Co-Authored-By: Claude` (or similar AI-attribution) trailer to commit messages.
- Do not change `TaskDrawer`/`ProjectDrawer`/`TimeEntryDrawer` layout or open/close state management — they stay local and inline, per explicit decision in the design spec.

---

### Task 1: `Select` row hover + action icon (style system)

**Files:**
- Modify: `packages\worklog_studio_style_system\lib\ui_kit\src\select\select_option.dart`
- Modify: `packages\worklog_studio_style_system\lib\ui_kit\src\select\select_content.dart`
- Modify: `packages\worklog_studio_style_system\lib\ui_kit\src\select\select.dart`
- Test: `packages\worklog_studio_style_system\test\ui_kit\select_content_test.dart`

**Interfaces:**
- Consumes: existing `SelectContent<T>`, `Select<T>`, `SelectOption<T>`, `AppThemeExtension` (`context.theme`).
- Produces: `SelectOption<T>` gains `onAction: VoidCallback?`, `actionIcon: IconData?`, `actionTooltip: String?`. `SelectContent<T>` gains a required `close: VoidCallback` constructor param. These are consumed by Task 5 (call sites) and by Task 2 (no interaction, just shares the file).

- [ ] **Step 1: Write the failing widget tests**

Create `packages\worklog_studio_style_system\test\ui_kit\select_content_test.dart`:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

void main() {
  Widget buildHarness({
    required List<SelectOption<String>> options,
    required ValueChanged<String> onSelect,
    VoidCallback? close,
  }) {
    return MaterialApp(
      theme: ThemeData(extensions: [AppThemeExtension.light()]),
      home: Scaffold(
        body: SelectContent<String>(
          searchable: false,
          searchController: TextEditingController(),
          options: options,
          selectedValue: null,
          onSelect: onSelect,
          searchQuery: '',
          close: close ?? () {},
        ),
      ),
    );
  }

  testWidgets(
    'tapping the row label selects the option',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        buildHarness(
          options: const [SelectOption(value: 'a', label: 'Option A')],
          onSelect: (value) => selected = value,
        ),
      );

      await tester.tap(find.text('Option A'));
      await tester.pump();

      expect(selected, 'a');
    },
  );

  testWidgets(
    'tapping the action icon calls onAction and close, but does not select',
    (tester) async {
      String? selected;
      var actionCalled = false;
      var closeCalled = false;

      await tester.pumpWidget(
        buildHarness(
          options: [
            SelectOption<String>(
              value: 'a',
              label: 'Option A',
              onAction: () => actionCalled = true,
              actionIcon: Icons.open_in_new,
            ),
          ],
          onSelect: (value) => selected = value,
          close: () => closeCalled = true,
        ),
      );

      // Action icon only becomes tappable while the row is hovered.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(find.text('Option A')));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Option A')));
      await tester.pump();

      final actionIconFinder = find.byIcon(Icons.open_in_new);
      expect(actionIconFinder, findsOneWidget);

      await tester.tap(actionIconFinder);
      await tester.pump();

      expect(actionCalled, isTrue);
      expect(closeCalled, isTrue);
      expect(selected, isNull);

      await gesture.removePointer();
    },
  );

  testWidgets(
    'action icon is not rendered when onAction is null',
    (tester) async {
      await tester.pumpWidget(
        buildHarness(
          options: const [SelectOption(value: 'a', label: 'Option A')],
          onSelect: (_) {},
        ),
      );

      expect(find.byIcon(Icons.open_in_new), findsNothing);
    },
  );
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run from `packages\worklog_studio_style_system`:
```
fvm flutter test test\ui_kit\select_content_test.dart --reporter expanded
```
Expected: FAIL — `SelectContent` has no `close` parameter, `SelectOption` has no `onAction`/`actionIcon`.

- [ ] **Step 3: Add the new fields to `SelectOption<T>`**

Replace the full contents of `select_option.dart`:

```dart
import 'package:flutter/material.dart';

/// Data model for Select option
class SelectOption<T> {
  final T value;
  final String label;
  final Widget? leading;

  /// Called when the row's small action icon is tapped instead of the row
  /// itself. Closes the popover but does not change the current selection.
  final VoidCallback? onAction;

  /// Icon for the action button. Defaults to [Icons.open_in_new] when
  /// [onAction] is set and this is left null.
  final IconData? actionIcon;

  final String? actionTooltip;

  const SelectOption({
    required this.value,
    required this.label,
    this.leading,
    this.onAction,
    this.actionIcon,
    this.actionTooltip,
  });
}
```

- [ ] **Step 4: Rewrite `select_content.dart`**

Replace the full contents of `select_content.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class SelectContent<T> extends StatefulWidget {
  final bool searchable;
  final TextEditingController searchController;
  final List<SelectOption<T>> options;
  final T? selectedValue;
  final ValueChanged<T> onSelect;
  final String searchQuery;
  final Widget Function(BuildContext context, String searchQuery)? actionBuilder;
  final Widget Function(BuildContext context, String searchQuery)? emptyBuilder;
  final ControlSize size;

  /// Closes the popover. Used both after a selection (already wrapped into
  /// [onSelect] by the caller) and after a row's action icon is tapped.
  final VoidCallback close;

  const SelectContent({
    super.key,
    required this.searchable,
    required this.searchController,
    required this.options,
    required this.selectedValue,
    required this.onSelect,
    required this.searchQuery,
    required this.close,
    this.actionBuilder,
    this.emptyBuilder,
    this.size = ControlSize.sm,
  });

  @override
  State<SelectContent<T>> createState() => _SelectContentState<T>();
}

class _SelectContentState<T> extends State<SelectContent<T>> {
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.searchable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final hasAction = widget.actionBuilder != null;

    final selectedOption = widget.options
        .where((o) => o.value == widget.selectedValue)
        .firstOrNull;

    final filteredOptions = widget.options.where((option) {
      if (!widget.searchable || widget.searchQuery.isEmpty) return true;
      return option.label.toLowerCase().contains(
        widget.searchQuery.toLowerCase(),
      );
    }).toList();

    final filteredWithoutSelected = filteredOptions
        .where((o) => o.value != widget.selectedValue)
        .toList();

    final List<Widget> listItems = [];

    if (hasAction) {
      listItems.add(widget.actionBuilder!(context, widget.searchQuery));
    }

    if (selectedOption != null) {
      listItems.add(
        _buildOptionItem(context, selectedOption, isSelected: true),
      );
    }

    final hasPinnedItems = listItems.isNotEmpty;
    if (hasPinnedItems && filteredWithoutSelected.isNotEmpty) {
      listItems.add(
        Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacings.sm),
          child: Divider(height: 1, color: palette.border.primary),
        ),
      );
    }

    if (filteredWithoutSelected.isEmpty && !hasPinnedItems) {
      listItems.add(
        Padding(
          padding: EdgeInsets.all(theme.spacings.lg),
          child: widget.emptyBuilder != null
              ? widget.emptyBuilder!(context, widget.searchQuery)
              : Text(
                  'No results found',
                  style: theme.commonTextStyles.body.copyWith(
                    color: palette.text.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
        ),
      );
    } else {
      listItems.addAll(
        filteredWithoutSelected.map(
          (option) => _buildOptionItem(context, option, isSelected: false),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: palette.background.surface,
        borderRadius: theme.radiuses.md.circular,
        border: Border.all(color: palette.border.primary),
        boxShadow: [theme.shadows.md],
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: listItems.length,
        itemBuilder: (context, index) => listItems[index],
      ),
    );
  }

  Widget _buildOptionItem(
    BuildContext context,
    SelectOption<T> option, {
    required bool isSelected,
  }) {
    return _SelectOptionRow<T>(
      option: option,
      isSelected: isSelected,
      size: widget.size,
      onSelect: () => widget.onSelect(option.value),
      onAction: option.onAction == null
          ? null
          : () {
              option.onAction!();
              widget.close();
            },
    );
  }
}

class _SelectOptionRow<T> extends StatefulWidget {
  final SelectOption<T> option;
  final bool isSelected;
  final ControlSize size;
  final VoidCallback onSelect;
  final VoidCallback? onAction;

  const _SelectOptionRow({
    required this.option,
    required this.isSelected,
    required this.size,
    required this.onSelect,
    required this.onAction,
  });

  @override
  State<_SelectOptionRow<T>> createState() => _SelectOptionRowState<T>();
}

class _SelectOptionRowState<T> extends State<_SelectOptionRow<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final tokens = theme.controlSize(widget.size);
    final option = widget.option;
    final isSelected = widget.isSelected;

    Widget? actionIcon;
    if (widget.onAction != null) {
      final icon = InkWell(
        borderRadius: theme.radiuses.sm.circular,
        onTap: widget.onAction,
        child: Padding(
          padding: EdgeInsets.all(theme.spacings.xxs),
          child: Icon(
            option.actionIcon ?? Icons.open_in_new,
            size: 14,
            color: palette.text.secondary,
          ),
        ),
      );
      actionIcon = option.actionTooltip != null
          ? Tooltip(message: option.actionTooltip!, child: icon)
          : icon;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onSelect,
        child: Stack(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.horizontalPadding,
                vertical: tokens.verticalPadding == 0
                    ? theme.spacings.sm
                    : tokens.verticalPadding,
              ),
              color: isSelected
                  ? palette.accent.primary.withValues(alpha: 0.08)
                  : (_isHovered ? palette.background.surfaceMuted : null),
              child: Row(
                children: [
                  if (option.leading != null) ...[
                    option.leading!,
                    SizedBox(width: theme.spacings.sm),
                  ],
                  Expanded(
                    child: Text(
                      option.label,
                      style: tokens.textStyle.copyWith(
                        color: isSelected
                            ? palette.accent.primary
                            : palette.text.primary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check,
                      size: tokens.iconSize,
                      color: palette.accent.primary,
                    ),
                ],
              ),
            ),
            if (actionIcon != null)
              Positioned(
                top: theme.spacings.xs,
                right: theme.spacings.xs,
                child: AnimatedOpacity(
                  opacity: _isHovered ? 1 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: IgnorePointer(
                    ignoring: !_isHovered,
                    child: actionIcon,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Update `select.dart`'s `contentBuilder` to pass `close`**

In `select.dart`, inside `_SelectState.build`, the `contentBuilder` currently returns:

```dart
      contentBuilder: (context, close) {
        return SelectContent<T>(
          searchable: widget.searchable,
          searchController: _searchController,
          options: widget.options,
          selectedValue: _currentValue,
          onSelect: (value) {
            _handleSelect(value);
            close();
          },
          searchQuery: _searchQuery,
          size: widget.size,
          actionBuilder: widget.actionBuilder != null
              ? (context, query) => widget.actionBuilder!(context, query, close)
              : null,
          emptyBuilder: widget.emptyBuilder,
        );
      },
```

Add `close: close,` right after `onSelect`:

```dart
      contentBuilder: (context, close) {
        return SelectContent<T>(
          searchable: widget.searchable,
          searchController: _searchController,
          options: widget.options,
          selectedValue: _currentValue,
          onSelect: (value) {
            _handleSelect(value);
            close();
          },
          close: close,
          searchQuery: _searchQuery,
          size: widget.size,
          actionBuilder: widget.actionBuilder != null
              ? (context, query) => widget.actionBuilder!(context, query, close)
              : null,
          emptyBuilder: widget.emptyBuilder,
        );
      },
```

- [ ] **Step 6: Run tests to verify they pass**

Run from `packages\worklog_studio_style_system`:
```
fvm flutter test test\ui_kit\select_content_test.dart --reporter expanded
```
Expected: PASS (3 tests).

- [ ] **Step 7: Run the full style-system test suite and analyzer**

```
fvm flutter test --reporter expanded
fvm flutter analyze
```
Expected: no new failures.

- [ ] **Step 8: Commit**

```bash
git add packages/worklog_studio_style_system/lib/ui_kit/src/select/select_option.dart packages/worklog_studio_style_system/lib/ui_kit/src/select/select_content.dart packages/worklog_studio_style_system/lib/ui_kit/src/select/select.dart packages/worklog_studio_style_system/test/ui_kit/select_content_test.dart
git commit -m "feat(style-system): add hover state and action icon to Select rows"
```

---

### Task 2: Popup `minWidth` (style system)

**Files:**
- Modify: `packages\worklog_studio_style_system\lib\ui_kit\src\popover\popover_primitive.dart`
- Modify: `packages\worklog_studio_style_system\lib\ui_kit\src\combobox\combobox.dart`
- Modify: `packages\worklog_studio_style_system\lib\ui_kit\src\select\select.dart`
- Test: `packages\worklog_studio_style_system\test\ui_kit\select_min_width_test.dart`

**Interfaces:**
- Consumes: `Select<T>` from Task 1 (already modified, unaffected by this task's changes other than adding `minWidth`).
- Produces: `Select<T>.minWidth` (defaults to `240`), threaded through `Combobox.minWidth` and `PopoverPrimitive.minWidth`. No other task depends on this directly.

- [ ] **Step 1: Write the failing widget test**

Create `packages\worklog_studio_style_system\test\ui_kit\select_min_width_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

void main() {
  testWidgets(
    'popup width expands to minWidth when the trigger is narrower',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AppThemeExtension.light()]),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 80,
                child: Select<String>(
                  minWidth: 240,
                  placeholder: 'Pick',
                  options: const [SelectOption(value: 'a', label: 'Option A')],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SelectTrigger));
      await tester.pumpAndSettle();

      final contentSize = tester.getSize(find.byType(SelectContent<String>));
      expect(contentSize.width, 240);
    },
  );

  testWidgets(
    'popup matches trigger width when trigger already exceeds minWidth',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AppThemeExtension.light()]),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: Select<String>(
                  minWidth: 240,
                  placeholder: 'Pick',
                  options: const [SelectOption(value: 'a', label: 'Option A')],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SelectTrigger));
      await tester.pumpAndSettle();

      final contentSize = tester.getSize(find.byType(SelectContent<String>));
      expect(contentSize.width, 320);
    },
  );
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run from `packages\worklog_studio_style_system`:
```
fvm flutter test test\ui_kit\select_min_width_test.dart --reporter expanded
```
Expected: FAIL — `Select` has no `minWidth` parameter (and before Task 1's fixed-width-240 removal, the first test would also fail on the width assertion).

- [ ] **Step 3: Add `minWidth` to `PopoverPrimitive`**

In `popover_primitive.dart`, add the field next to `matchTriggerWidth`:

```dart
  final bool
  matchTriggerWidth; // Для Select/Combobox (ширина списка = ширине инпута)
  final double? minWidth;
```

Add it to the constructor:

```dart
    this.matchTriggerWidth = false,
    this.minWidth,
```

In `_show()`, replace:

```dart
    // Получаем размер триггера, чтобы подогнать ширину (нужно для Select)
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final triggerWidth = renderBox?.size.width ?? 200.0;
```

with:

```dart
    // Получаем размер триггера, чтобы подогнать ширину (нужно для Select)
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final triggerWidth = renderBox?.size.width ?? 200.0;
    final minWidth = widget.minWidth;
    final effectiveWidth = widget.matchTriggerWidth
        ? (minWidth != null && minWidth > triggerWidth ? minWidth : triggerWidth)
        : widget.width;
```

And replace the `SizedBox` width usage:

```dart
                  width: widget.matchTriggerWidth ? triggerWidth : widget.width,
```

with:

```dart
                  width: effectiveWidth,
```

- [ ] **Step 4: Thread `minWidth` through `Combobox`**

In `combobox.dart`, add the field next to `matchTriggerWidth`:

```dart
  final bool matchTriggerWidth;
  final double? minWidth;
```

Add to the constructor:

```dart
    this.matchTriggerWidth = false,
    this.minWidth,
```

In `build()`, pass it to `PopoverPrimitive`:

```dart
      matchTriggerWidth: widget.matchTriggerWidth,
      minWidth: widget.minWidth,
```

- [ ] **Step 5: Thread `minWidth` through `Select` and remove `SelectContent`'s fixed width**

In `select.dart`, add the field next to `matchTriggerWidth`:

```dart
  final bool matchTriggerWidth;
  final double? minWidth;
```

Add to the constructor, defaulting to `240` (the value `SelectContent` used to hardcode, so default visual behavior is unchanged):

```dart
    this.matchTriggerWidth = true,
    this.minWidth = 240,
```

In `build()`, pass it to `Combobox`:

```dart
      matchTriggerWidth: widget.matchTriggerWidth,
      minWidth: widget.minWidth,
```

`SelectContent`'s `Container` no longer has a fixed `width: 240` — that was already removed in Task 1 Step 4 (the rewritten `select_content.dart` has no `width:` on the outer `Container`, only `constraints: const BoxConstraints(maxHeight: 300)`). Confirm this is the case; if Task 1 was skipped or done differently, remove the `width: 240,` line from `SelectContent`'s `build()` now.

- [ ] **Step 6: Run tests to verify they pass**

```
fvm flutter test test\ui_kit\select_min_width_test.dart --reporter expanded
```
Expected: PASS (2 tests).

- [ ] **Step 7: Run the full style-system test suite and analyzer**

```
fvm flutter test --reporter expanded
fvm flutter analyze
```
Expected: no new failures.

- [ ] **Step 8: Commit**

```bash
git add packages/worklog_studio_style_system/lib/ui_kit/src/popover/popover_primitive.dart packages/worklog_studio_style_system/lib/ui_kit/src/combobox/combobox.dart packages/worklog_studio_style_system/lib/ui_kit/src/select/select.dart packages/worklog_studio_style_system/test/ui_kit/select_min_width_test.dart
git commit -m "feat(style-system): let Select popup exceed trigger width via minWidth"
```

---

### Task 3: `AppNavigationController`

**Files:**
- Create: `apps\worklog_studio\lib\core\services\app_navigation_controller.dart`
- Test: `apps\worklog_studio\test\core\app_navigation_controller_test.dart`

**Interfaces:**
- Consumes: nothing (pure Dart class, no Flutter dependency).
- Produces: `AppNavigationController` with `registerHandlers({required void Function(String) openTask, required void Function(String) openProject, required void Function(String) openHistoryEntry})`, `openTask(String id)`, `openProject(String id)`, `openHistoryEntry(String id)`. Consumed by Task 4 (registration in `AppShell`) and Task 5 (call sites).

- [ ] **Step 1: Write the failing unit tests**

Create `apps\worklog_studio\test\core\app_navigation_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/app_navigation_controller.dart';

void main() {
  group('AppNavigationController', () {
    test('openTask is a no-op before handlers are registered', () {
      final controller = AppNavigationController();
      expect(() => controller.openTask('t1'), returnsNormally);
    });

    test('openProject is a no-op before handlers are registered', () {
      final controller = AppNavigationController();
      expect(() => controller.openProject('p1'), returnsNormally);
    });

    test('openHistoryEntry is a no-op before handlers are registered', () {
      final controller = AppNavigationController();
      expect(() => controller.openHistoryEntry('e1'), returnsNormally);
    });

    test('openTask calls the registered handler with the given id', () {
      final controller = AppNavigationController();
      String? receivedId;
      controller.registerHandlers(
        openTask: (id) => receivedId = id,
        openProject: (_) {},
        openHistoryEntry: (_) {},
      );

      controller.openTask('t1');

      expect(receivedId, 't1');
    });

    test('openProject calls the registered handler with the given id', () {
      final controller = AppNavigationController();
      String? receivedId;
      controller.registerHandlers(
        openTask: (_) {},
        openProject: (id) => receivedId = id,
        openHistoryEntry: (_) {},
      );

      controller.openProject('p1');

      expect(receivedId, 'p1');
    });

    test('openHistoryEntry calls the registered handler with the given id', () {
      final controller = AppNavigationController();
      String? receivedId;
      controller.registerHandlers(
        openTask: (_) {},
        openProject: (_) {},
        openHistoryEntry: (id) => receivedId = id,
      );

      controller.openHistoryEntry('e1');

      expect(receivedId, 'e1');
    });

    test('registerHandlers replaces previously registered handlers', () {
      final controller = AppNavigationController();
      var firstCalled = false;
      var secondCalled = false;

      controller.registerHandlers(
        openTask: (_) => firstCalled = true,
        openProject: (_) {},
        openHistoryEntry: (_) {},
      );
      controller.registerHandlers(
        openTask: (_) => secondCalled = true,
        openProject: (_) {},
        openHistoryEntry: (_) {},
      );

      controller.openTask('t1');

      expect(firstCalled, isFalse);
      expect(secondCalled, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run from `apps\worklog_studio`:
```
fvm flutter test test\core\app_navigation_controller_test.dart --reporter expanded
```
Expected: FAIL — `package:worklog_studio/core/services/app_navigation_controller.dart` does not exist.

- [ ] **Step 3: Implement `AppNavigationController`**

Create `apps\worklog_studio\lib\core\services\app_navigation_controller.dart`:

```dart
/// Lets any widget request the app switch to an entity's own page and open
/// its existing edit drawer, without needing a direct reference to AppShell.
/// AppShell registers the real handlers once, at startup, via
/// [registerHandlers].
class AppNavigationController {
  void Function(String taskId)? _openTaskHandler;
  void Function(String projectId)? _openProjectHandler;
  void Function(String entryId)? _openHistoryEntryHandler;

  void registerHandlers({
    required void Function(String taskId) openTask,
    required void Function(String projectId) openProject,
    required void Function(String entryId) openHistoryEntry,
  }) {
    _openTaskHandler = openTask;
    _openProjectHandler = openProject;
    _openHistoryEntryHandler = openHistoryEntry;
  }

  void openTask(String taskId) => _openTaskHandler?.call(taskId);

  void openProject(String projectId) => _openProjectHandler?.call(projectId);

  void openHistoryEntry(String entryId) =>
      _openHistoryEntryHandler?.call(entryId);
}
```

- [ ] **Step 4: Run tests to verify they pass**

```
fvm flutter test test\core\app_navigation_controller_test.dart --reporter expanded
```
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/core/services/app_navigation_controller.dart apps/worklog_studio/test/core/app_navigation_controller_test.dart
git commit -m "feat: add AppNavigationController for cross-page entity navigation"
```

---

### Task 4: Wire `AppNavigationController` into the app, add `ProjectsScreen` parity

**Files:**
- Modify: `apps\worklog_studio\lib\feature\app\app.dart`
- Modify: `apps\worklog_studio\lib\feature\app\layout\app_shell.dart`
- Modify: `apps\worklog_studio\lib\feature\projects\presentation\projects_page.dart`

**Interfaces:**
- Consumes: `AppNavigationController` (Task 3), `EntityResolver.getResolvedProjects()` (existing), `DrawerControllerState<Project>` (existing).
- Produces: `ProjectsScreen({this.initialSelectedProjectId})`; `_AppShellState._openProject(String projectId)`; `AppNavigationController` available via `Provider` above `AppShell`. Consumed by Task 5.

- [ ] **Step 1: Provide `AppNavigationController` above `AppShell`**

In `app.dart`, add the import:

```dart
import 'package:worklog_studio/core/services/app_navigation_controller.dart';
```

In `MainApp.build`'s `MultiProvider.providers` list, add a new entry (order doesn't matter relative to the others — it has no dependency on them):

```dart
        Provider<AppNavigationController>(
          create: (_) => AppNavigationController(),
        ),
```

- [ ] **Step 2: Add `ProjectsScreen.initialSelectedProjectId` with the same pattern as `TasksScreen`**

In `projects_page.dart`, add the import (mirrors `tasks_page.dart`):

```dart
import 'package:collection/collection.dart';
```
(Already present — confirm it's there; if not, add it.)

Change the widget declaration from:

```dart
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}
```

to:

```dart
class ProjectsScreen extends StatefulWidget {
  final String? initialSelectedProjectId;

  const ProjectsScreen({super.key, this.initialSelectedProjectId});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}
```

Change `_ProjectsScreenState` from:

```dart
class _ProjectsScreenState extends State<ProjectsScreen> {
  DrawerControllerState<Project> _drawerState = DrawerControllerState.closed();
  ProjectViewMode _viewMode = ProjectViewMode.table;

  void _handleProjectSelected(Project project) {
```

to:

```dart
class _ProjectsScreenState extends State<ProjectsScreen> {
  DrawerControllerState<Project> _drawerState = DrawerControllerState.closed();
  ProjectViewMode _viewMode = ProjectViewMode.table;
  final GlobalKey _selectedRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedProjectId != null) {
      _selectProjectById(widget.initialSelectedProjectId!);
    }
  }

  @override
  void didUpdateWidget(covariant ProjectsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedProjectId != null &&
        widget.initialSelectedProjectId != oldWidget.initialSelectedProjectId) {
      _selectProjectById(widget.initialSelectedProjectId!);
    }
  }

  void _selectProjectById(String projectId) {
    final resolvedProject = context
        .read<EntityResolver>()
        .getResolvedProjects()
        .firstWhereOrNull((p) => p.id == projectId);
    if (resolvedProject != null) {
      setState(() {
        _drawerState = DrawerControllerState.edit(resolvedProject.project);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final rowContext = _selectedRowKey.currentContext;
        if (rowContext != null) {
          Scrollable.ensureVisible(
            rowContext,
            duration: const Duration(milliseconds: 300),
            alignment: 0.5,
          );
        }
      });
    }
  }

  void _handleProjectSelected(Project project) {
```

In the same state class's `build()`, pass the row key down to `ProjectList` and use it to mark the selected row, mirroring `TaskList`. Change:

```dart
        Expanded(
          child: ProjectList(
            projects: resolvedProjects,
            selectedProject: _drawerState.entity,
            onProjectSelected: _handleProjectSelected,
            onCreateProject: _handleCreateProject,
            viewMode: _viewMode,
            onViewModeChanged: (mode) => setState(() => _viewMode = mode),
          ),
        ),
```

to:

```dart
        Expanded(
          child: ProjectList(
            projects: resolvedProjects,
            selectedProject: _drawerState.entity,
            selectedRowKey: _selectedRowKey,
            onProjectSelected: _handleProjectSelected,
            onCreateProject: _handleCreateProject,
            viewMode: _viewMode,
            onViewModeChanged: (mode) => setState(() => _viewMode = mode),
          ),
        ),
```

In `ProjectList`, add the `selectedRowKey` field/param (mirrors `TaskList`):

```dart
class ProjectList extends StatelessWidget {
  final List<ResolvedProject> projects;
  final Project? selectedProject;
  final GlobalKey? selectedRowKey;
  final ValueChanged<Project> onProjectSelected;
  final VoidCallback onCreateProject;
  final ProjectViewMode viewMode;
  final ValueChanged<ProjectViewMode> onViewModeChanged;

  const ProjectList({
    super.key,
    required this.projects,
    required this.selectedProject,
    this.selectedRowKey,
    required this.onProjectSelected,
    required this.onCreateProject,
    required this.viewMode,
    required this.onViewModeChanged,
  });
```

In `ProjectList.build()`, thread the key into `WsTable`'s `rowKeyBuilder` and into the selected `ProjectCard`'s `key`. Change:

```dart
                  ? WsTable<ResolvedProject>(
                      data: projects,
                      selectedItem: projects.firstWhereOrNull(
                        (e) => e.id == selectedProject?.id,
                      ),
                      onRowTap: (item) => onProjectSelected(item.project),
                      isSelected: (item, selected) => item.id == selected?.id,
                      columns: _getTableColumns(theme),
                    )
                  : Column(
                      spacing: theme.spacings.lg,
                      children: projects.map((project) {
                        final isSelected = selectedProject?.id == project.id;
                        return ProjectCard(
                          project: project,
                          isSelected: isSelected,
                          onTap: () => onProjectSelected(project.project),
                        );
                      }).toList(),
                    ),
```

to:

```dart
                  ? WsTable<ResolvedProject>(
                      data: projects,
                      selectedItem: projects.firstWhereOrNull(
                        (e) => e.id == selectedProject?.id,
                      ),
                      rowKeyBuilder: (item) =>
                          item.id == selectedProject?.id ? selectedRowKey : null,
                      onRowTap: (item) => onProjectSelected(item.project),
                      isSelected: (item, selected) => item.id == selected?.id,
                      columns: _getTableColumns(theme),
                    )
                  : Column(
                      spacing: theme.spacings.lg,
                      children: projects.map((project) {
                        final isSelected = selectedProject?.id == project.id;
                        return ProjectCard(
                          key: isSelected ? selectedRowKey : null,
                          project: project,
                          isSelected: isSelected,
                          onTap: () => onProjectSelected(project.project),
                        );
                      }).toList(),
                    ),
```

- [ ] **Step 3: Add `_openProject` to `AppShell` and register handlers**

In `app_shell.dart`, add the pending-id field next to `_pendingTaskId`:

```dart
  String? _pendingHistoryEntryId;
  int _historyCreateToken = 0;
  String? _pendingTaskId;
  String? _pendingProjectId;
  StreamSubscription<String>? _navSub;
```

In `initState`, register the controller's handlers (this runs once; `context.read` is safe here since `Provider<AppNavigationController>` is an ancestor supplied in `app.dart`):

```dart
  @override
  void initState() {
    super.initState();
    context.read<AppNavigationController>().registerHandlers(
      openTask: _openTask,
      openProject: _openProject,
      openHistoryEntry: _openHistoryEntry,
    );
    _navSub = DesktopServiceRegistry.instance.navigationStream.listen((route) {
      if (route == 'history') {
        _onRouteSelected(AppRoute.history);
      } else if (route == 'tasks') {
        _onRouteSelected(AppRoute.tasks);
      } else if (route == 'projects') {
        _onRouteSelected(AppRoute.projects);
      }
    });
  }
```

Add `_openProject` next to `_openTask`:

```dart
  void _openTask(String taskId) {
    setState(() {
      _pendingTaskId = taskId;
      _currentRoute = AppRoute.tasks;
    });
  }

  void _openProject(String projectId) {
    setState(() {
      _pendingProjectId = projectId;
      _currentRoute = AppRoute.projects;
    });
  }
```

Add the import:

```dart
import 'package:worklog_studio/core/services/app_navigation_controller.dart';
```

In `_buildActiveScreen()`, pass the pending id into `ProjectsScreen`. Change:

```dart
        const ProjectsScreen(),
        TasksScreen(initialSelectedTaskId: _pendingTaskId),
```

to:

```dart
        ProjectsScreen(initialSelectedProjectId: _pendingProjectId),
        TasksScreen(initialSelectedTaskId: _pendingTaskId),
```

- [ ] **Step 4: Run the app's existing test suite**

Run from `apps\worklog_studio`:
```
fvm flutter test test/core/ test/feature/ --reporter expanded
```
Expected: PASS, no regressions (this task adds no new business logic of its own — `_openProject`/`_selectProjectById` are UI-only state mirroring already-untested `_openTask`/`_selectTaskById`, exempt per the TDD rule).

- [ ] **Step 5: Run the analyzer**

```
fvm flutter analyze
```
Expected: no new failures.

- [ ] **Step 6: Manually verify**

Run the app (`fvm flutter run -d windows` or your usual dev flow) and confirm:
- Projects page still opens/loads.
- Tasks page behavior is unchanged.
- No exceptions on app startup (the new `Provider<AppNavigationController>` must not break the provider tree).

- [ ] **Step 7: Commit**

```bash
git add apps/worklog_studio/lib/feature/app/app.dart apps/worklog_studio/lib/feature/app/layout/app_shell.dart apps/worklog_studio/lib/feature/projects/presentation/projects_page.dart
git commit -m "feat: register AppNavigationController and add ProjectsScreen deep-link parity"
```

---

### Task 5: Wire action icons at the four call sites

**Files:**
- Modify: `apps\worklog_studio\lib\feature\app\layout\app_shell.dart`
- Modify: `apps\worklog_studio\lib\feature\tasks\presentation\components\tasks_drawer.dart`
- Modify: `apps\worklog_studio\lib\feature\history\presentation\components\time_entry_drawer.dart`

**Interfaces:**
- Consumes: `SelectOption.onAction`/`actionIcon`/`actionTooltip` (Task 1), `AppNavigationController.openProject`/`openTask` (Task 3, registered in Task 4), `_AppShellState._openProject`/`_openTask` (Task 4).
- Produces: nothing consumed by later tasks — this is the final task.

- [ ] **Step 1: Wire the tracking panel's project selector in `app_shell.dart`**

In `_buildProjectSelector`, the `options` mapping currently is:

```dart
    final options = projects.map((p) {
      final initials = BadgeUtils.getProjectInitials(p.name);
      final colors = BadgeUtils.getBadgeColor(p.id);
      return SelectOption(
        value: p.id,
        label: p.name,
        leading: WsInitialBadge(
          initials: initials,
          backgroundColor: colors.$1,
          textColor: colors.$2,
          size: WsInitialBadgeSize.small,
        ),
      );
    }).toList();
```

Change it to:

```dart
    final options = projects.map((p) {
      final initials = BadgeUtils.getProjectInitials(p.name);
      final colors = BadgeUtils.getBadgeColor(p.id);
      return SelectOption(
        value: p.id,
        label: p.name,
        leading: WsInitialBadge(
          initials: initials,
          backgroundColor: colors.$1,
          textColor: colors.$2,
          size: WsInitialBadgeSize.small,
        ),
        onAction: () => _openProject(p.id),
        // TODO: l10n
        actionTooltip: 'Open project',
      );
    }).toList();
```

- [ ] **Step 2: Wire the tracking panel's task selector in `app_shell.dart`**

In `_buildTaskSelector`, the `options` mapping currently is:

```dart
    final options = filteredTasks.map((t) {
      final project = projectTaskState.projects.firstWhereOrNull(
        (p) => p.id == t.projectId,
      );
      final initials = BadgeUtils.getTaskInitials(t.title, project?.name ?? '');
      final colors = BadgeUtils.getBadgeColor(t.id);
      return SelectOption(
        value: t.id,
        label: t.title,
        leading: WsInitialBadge(
          initials: initials,
          backgroundColor: colors.$1,
          textColor: colors.$2,
          size: WsInitialBadgeSize.small,
        ),
      );
    }).toList();
```

Change it to:

```dart
    final options = filteredTasks.map((t) {
      final project = projectTaskState.projects.firstWhereOrNull(
        (p) => p.id == t.projectId,
      );
      final initials = BadgeUtils.getTaskInitials(t.title, project?.name ?? '');
      final colors = BadgeUtils.getBadgeColor(t.id);
      return SelectOption(
        value: t.id,
        label: t.title,
        leading: WsInitialBadge(
          initials: initials,
          backgroundColor: colors.$1,
          textColor: colors.$2,
          size: WsInitialBadgeSize.small,
        ),
        onAction: () => _openTask(t.id),
        // TODO: l10n
        actionTooltip: 'Open task',
      );
    }).toList();
```

- [ ] **Step 3: Wire the project select nested in `TaskDrawer` (`tasks_drawer.dart`)**

Add the import:

```dart
import 'package:worklog_studio/core/services/app_navigation_controller.dart';
```

The `options:` mapping inside the project `Select` (around the `Consumer<ProjectTaskState>` builder) currently is:

```dart
                                        options: state.projects.map((p) {
                                          final initials =
                                              BadgeUtils.getProjectInitials(
                                                p.name,
                                              );
                                          final colors =
                                              BadgeUtils.getBadgeColor(p.id);
                                          return SelectOption(
                                            value: p.id,
                                            label: p.name,
                                            leading: WsInitialBadge(
                                              initials: initials,
                                              backgroundColor: colors.$1,
                                              textColor: colors.$2,
                                              size: WsInitialBadgeSize.small,
                                            ),
                                          );
                                        }).toList(),
```

Change it to:

```dart
                                        options: state.projects.map((p) {
                                          final initials =
                                              BadgeUtils.getProjectInitials(
                                                p.name,
                                              );
                                          final colors =
                                              BadgeUtils.getBadgeColor(p.id);
                                          return SelectOption(
                                            value: p.id,
                                            label: p.name,
                                            leading: WsInitialBadge(
                                              initials: initials,
                                              backgroundColor: colors.$1,
                                              textColor: colors.$2,
                                              size: WsInitialBadgeSize.small,
                                            ),
                                            onAction: () => context
                                                .read<AppNavigationController>()
                                                .openProject(p.id),
                                            // TODO: l10n
                                            actionTooltip: 'Open project',
                                          );
                                        }).toList(),
```

- [ ] **Step 4: Wire the project select nested in `TimeEntryDrawer` (`time_entry_drawer.dart`)**

Add the import:

```dart
import 'package:worklog_studio/core/services/app_navigation_controller.dart';
```

The project select's `options:` mapping currently is:

```dart
                                options: state.projects.map((p) {
                                  final initials =
                                      BadgeUtils.getProjectInitials(p.name);
                                  final colors = BadgeUtils.getBadgeColor(p.id);
                                  return SelectOption(
                                    value: p.id,
                                    label: p.name,
                                    leading: WsInitialBadge(
                                      initials: initials,
                                      backgroundColor: colors.$1,
                                      textColor: colors.$2,
                                      size: WsInitialBadgeSize.small,
                                    ),
                                  );
                                }).toList(),
```

Change it to:

```dart
                                options: state.projects.map((p) {
                                  final initials =
                                      BadgeUtils.getProjectInitials(p.name);
                                  final colors = BadgeUtils.getBadgeColor(p.id);
                                  return SelectOption(
                                    value: p.id,
                                    label: p.name,
                                    leading: WsInitialBadge(
                                      initials: initials,
                                      backgroundColor: colors.$1,
                                      textColor: colors.$2,
                                      size: WsInitialBadgeSize.small,
                                    ),
                                    onAction: () => context
                                        .read<AppNavigationController>()
                                        .openProject(p.id),
                                    // TODO: l10n
                                    actionTooltip: 'Open project',
                                  );
                                }).toList(),
```

- [ ] **Step 5: Wire the task select nested in `TimeEntryDrawer` (`time_entry_drawer.dart`)**

Find the task select's `options:` mapping further down the same file (the one filtered by `t.projectId == _draft.projectId`). It currently builds a `SelectOption` per task with `value`, `label`, and `leading`. Add `onAction` and `actionTooltip` the same way:

```dart
                                  return SelectOption(
                                    value: t.id,
                                    label: t.title,
                                    leading: WsInitialBadge(
                                      initials: initials,
                                      backgroundColor: colors.$1,
                                      textColor: colors.$2,
                                      size: WsInitialBadgeSize.small,
                                    ),
                                    onAction: () => context
                                        .read<AppNavigationController>()
                                        .openTask(t.id),
                                    // TODO: l10n
                                    actionTooltip: 'Open task',
                                  );
```

Keep the rest of that builder (the `initials`/`colors` computation, the `.map`/`.where`/`.toList()` chain) exactly as it is — only the returned `SelectOption` gains the two new named arguments.

- [ ] **Step 6: Run the analyzer**

```
fvm flutter analyze
```
Expected: no new failures. (No new automated tests for this task — it's mechanical wiring of already-tested building blocks into UI-only call sites, exempt per the TDD rule.)

- [ ] **Step 7: Manually verify end-to-end**

Run the app and check, for each of the four selects:
- Hovering a row shows the subtle background tint and the small action icon fades in (top-right of the row).
- Clicking the action icon switches to the target page (Projects or Tasks), opens that entity's drawer, and scrolls it into view if it's below the fold — without changing the original select's value.
- Clicking anywhere else on the row still selects normally, with no action icon interference.

- [ ] **Step 8: Commit**

```bash
git add apps/worklog_studio/lib/feature/app/layout/app_shell.dart apps/worklog_studio/lib/feature/tasks/presentation/components/tasks_drawer.dart apps/worklog_studio/lib/feature/history/presentation/components/time_entry_drawer.dart
git commit -m "feat: wire navigable action icon into tracking panel and nested drawer selects"
```
