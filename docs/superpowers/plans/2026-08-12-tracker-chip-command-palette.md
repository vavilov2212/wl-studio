# Tracker Chip + Command Palette Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the always-expanded 56px TopAppBar tracker panel with a minimal 36px chip bar and on-demand command-palette overlay.

**Architecture:** The current `GlobalTimeTrackerPanel` is split into two new widgets: `TrackerPanelForm` (the shared form body) and `TrackerCommandPalette` (the overlay shell). A new `TrackerChipBar` replaces `TopAppBar` and manages the overlay lifecycle. The BLoC/cubit layer is untouched.

**Tech Stack:** Flutter, flutter_bloc, existing `WorklogStudioAssets`, `WorklogStudioStyleSystem` design tokens.

## Global Constraints

- All paths use backslashes; run all commands from the repo root via `fvm`.
- Never run global `flutter` or `dart` - always prefix with `fvm`.
- Never import from `*.freezed.dart` or `*.g.dart`.
- Never crawl `build\`, `.dart_tool\`, `.fvm\`, `.git\`.
- No hardcoded colors or paddings in `apps\` - always use `context.theme.*` tokens.
- No `Co-Authored-By` trailer in commit messages.
- UI-only widgets are exempt from TDD per `apps\worklog_studio\CLAUDE.md`. Verification is `fvm flutter analyze` plus visual review in the running app.

---

## File Map

| Path | Status | Responsibility |
|------|--------|----------------|
| `apps\worklog_studio\lib\feature\time_tracker\presentation\tracker_panel_form.dart` | CREATE | Stateful form body: Project select, Task select, Comment input, footer divider + timer + start/stop button. Shared between overlay and bottom sheet. |
| `apps\worklog_studio\lib\feature\time_tracker\presentation\tracker_command_palette.dart` | CREATE | Overlay shell: full-screen backdrop + centered 520px panel. Contains `TrackerPanelForm`. Handles Esc key. |
| `apps\worklog_studio\lib\feature\time_tracker\presentation\tracker_chip_bar.dart` | CREATE | Compact 36px bar. Shows idle or running state from BLoC. Manages `OverlayEntry` lifecycle. Dispatches to overlay (desktop) or bottom sheet (mobile). |
| `apps\worklog_studio\lib\feature\app\layout\app_bar\top_app_bar.dart` | MODIFY | Swap `GlobalTimeTrackerPanel` for `TrackerChipBar`. Remove height padding from old expanded layout. |
| `apps\worklog_studio\lib\feature\time_tracker\presentation\global_time_tracker_panel.dart` | DELETE | Fully replaced by `TrackerPanelForm` + `TrackerChipBar`. |

---

## Task 1: TrackerPanelForm

Extract the form fields + footer from `GlobalTimeTrackerPanel` into a standalone
`StatefulWidget`. This widget is the shared body used by both the desktop overlay
and the mobile bottom sheet.

**Files:**
- Create: `apps\worklog_studio\lib\feature\time_tracker\presentation\tracker_panel_form.dart`

**Interfaces:**
- Consumes: `TrackerPanelCubit` (via `context.read`), `TimeTrackerBloc` (via `context`), `ProjectTaskState` (via `context.select`)
- Produces: `TrackerPanelForm({required ValueChanged<String> onOpenProject, required ValueChanged<String> onOpenTask, VoidCallback? onDone})`

---

- [ ] **Step 1: Create the file with the widget skeleton**

```dart
// apps\worklog_studio\lib\feature\time_tracker\presentation\tracker_panel_form.dart

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field_controller.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/tracker_panel_cubit.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/active_timer_text.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class TrackerPanelForm extends StatefulWidget {
  final ValueChanged<String> onOpenProject;
  final ValueChanged<String> onOpenTask;
  final VoidCallback? onDone;

  const TrackerPanelForm({
    super.key,
    required this.onOpenProject,
    required this.onOpenTask,
    this.onDone,
  });

  @override
  State<TrackerPanelForm> createState() => _TrackerPanelFormState();
}
```

---

- [ ] **Step 2: Add state, controllers, and dispose**

```dart
class _TrackerPanelFormState extends State<TrackerPanelForm> {
  final TextEditingController _commentController = TextEditingController();
  final InlineFieldController _projectFieldController = InlineFieldController();
  final InlineFieldController _taskFieldController = InlineFieldController();
  final InlineFieldController _commentFieldController = InlineFieldController();

  @override
  void dispose() {
    _commentController.dispose();
    _projectFieldController.dispose();
    _taskFieldController.dispose();
    _commentFieldController.dispose();
    super.dispose();
  }
```

---

- [ ] **Step 3: Implement build - sync comment controller from cubit, then render the column**

```dart
  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return BlocListener<TrackerPanelCubit, TrackerPanelState>(
      listenWhen: (prev, curr) => prev.draftComment != curr.draftComment,
      listener: (context, state) {
        if (_commentController.text != state.draftComment) {
          _commentController.text = state.draftComment;
        }
      },
      child: BlocBuilder<TimeTrackerBloc, TimeTrackerBlocState>(
        buildWhen: (prev, curr) =>
            prev.isRunning != curr.isRunning ||
            prev.activeEntryOrNull != curr.activeEntryOrNull,
        builder: (context, state) {
          final isRunning = state.isRunning;
          final draftProjectId =
              context.select<ProjectTaskState, String?>((s) => s.draftProjectId);
          final draftTaskId =
              context.select<ProjectTaskState, String?>((s) => s.draftTaskId);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel(context, 'Project'), // TODO: l10n
              SizedBox(height: theme.spacings.md),
              _buildProjectSelector(context, isRunning, draftProjectId),
              SizedBox(height: theme.spacings.lg),
              _fieldLabel(context, 'Task'), // TODO: l10n
              SizedBox(height: theme.spacings.md),
              _buildTaskSelector(context, isRunning, draftTaskId),
              SizedBox(height: theme.spacings.lg),
              _fieldLabel(context, 'Comment'), // TODO: l10n
              SizedBox(height: theme.spacings.md),
              _buildCommentInput(context, isRunning),
              SizedBox(height: theme.spacings.lg),
              Divider(color: palette.border.primary, height: 1),
              SizedBox(height: theme.spacings.lg),
              _buildFooter(context, isRunning, palette, theme, draftProjectId, draftTaskId),
            ],
          );
        },
      ),
    );
  }

  Widget _fieldLabel(BuildContext context, String text) {
    final theme = context.theme;
    return Text(
      text,
      style: theme.commonTextStyles.caption.copyWith(
        color: theme.colorsPalette.text.secondary,
      ),
    );
  }
```

---

- [ ] **Step 4: Implement _buildFooter**

```dart
  Widget _buildFooter(
    BuildContext context,
    bool isRunning,
    dynamic palette,
    AppThemeExtension theme,
    String? draftProjectId,
    String? draftTaskId,
  ) {
    final cubit = context.read<TrackerPanelCubit>();
    return Row(
      children: [
        ActiveTimerText(
          style: theme.commonTextStyles.h2.copyWith(
            color: isRunning ? palette.text.primary : palette.text.muted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const Spacer(),
        if (isRunning)
          PrimaryButton(
            type: ButtonType.danger,
            size: ButtonSize.sm,
            title: 'Stop', // TODO: l10n
            leftIcon: WorklogStudioAssets.vectors.squareFilled64Svg,
            onTap: () {
              cubit.stopTimer();
              widget.onDone?.call();
            },
          )
        else
          PrimaryButton(
            size: ButtonSize.sm,
            title: 'Start', // TODO: l10n
            leftIcon: WorklogStudioAssets.vectors.playFilled64Svg,
            onTap: () {
              cubit.startTimer();
              widget.onDone?.call();
            },
          ),
      ],
    );
  }
```

---

- [ ] **Step 5: Copy _buildProjectSelector verbatim from GlobalTimeTrackerPanel**

Open `apps\worklog_studio\lib\feature\time_tracker\presentation\global_time_tracker_panel.dart` lines 209-295 and copy the `_buildProjectSelector` method into `_TrackerPanelFormState`. Replace `widget.onOpenProject` references - they stay the same because `widget` still refers to `TrackerPanelForm`.

---

- [ ] **Step 6: Copy _buildTaskSelector verbatim from GlobalTimeTrackerPanel**

Copy lines 297-407 (`_buildTaskSelector`) from `global_time_tracker_panel.dart` into `_TrackerPanelFormState`. Same widget reference pattern applies.

---

- [ ] **Step 7: Copy _buildCommentInput verbatim from GlobalTimeTrackerPanel**

Copy lines 409-427 (`_buildCommentInput`) from `global_time_tracker_panel.dart` into `_TrackerPanelFormState`.

---

- [ ] **Step 8: Close the class brace and verify compilation**

```bash
cd apps\worklog_studio && fvm flutter analyze lib\feature\time_tracker\presentation\tracker_panel_form.dart
```

Expected: no errors. Fix any import or type issues before continuing.

---

- [ ] **Step 9: Commit**

```bash
git add apps\worklog_studio\lib\feature\time_tracker\presentation\tracker_panel_form.dart
git commit -m "feat(tracker): add TrackerPanelForm - extracted form body"
```

---

## Task 2: TrackerCommandPalette

A full-screen overlay widget. Renders a translucent backdrop and a centered 520px panel
containing `TrackerPanelForm`. Handles Esc key. Lifecycle (insert/remove) is managed by
the caller (`TrackerChipBar` in Task 3).

**Files:**
- Create: `apps\worklog_studio\lib\feature\time_tracker\presentation\tracker_command_palette.dart`

**Interfaces:**
- Consumes: `TrackerPanelForm(onOpenProject, onOpenTask, onDone: onClose)`
- Produces: `TrackerCommandPalette({required VoidCallback onClose, required ValueChanged<String> onOpenProject, required ValueChanged<String> onOpenTask})`

---

- [ ] **Step 1: Create the file**

```dart
// apps\worklog_studio\lib\feature\time_tracker\presentation\tracker_command_palette.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/tracker_panel_form.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class TrackerCommandPalette extends StatelessWidget {
  final VoidCallback onClose;
  final ValueChanged<String> onOpenProject;
  final ValueChanged<String> onOpenTask;

  const TrackerCommandPalette({
    super.key,
    required this.onClose,
    required this.onOpenProject,
    required this.onOpenTask,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Stack(
      children: [
        // Backdrop - closes on tap
        ModalBarrier(
          color: const Color.fromRGBO(0, 0, 0, 0.12),
          onDismiss: onClose,
          dismissible: true,
        ),
        // Panel
        Positioned(
          top: screenHeight * 0.18,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: 520,
              child: Material(
                color: palette.background.surface,
                borderRadius: BorderRadius.circular(theme.radiuses.lg),
                elevation: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.background.surface,
                    borderRadius: BorderRadius.circular(theme.radiuses.lg),
                    border: Border.all(color: palette.border.primary),
                    boxShadow: [theme.shadows.md],
                  ),
                  padding: EdgeInsets.all(theme.spacings.xl),
                  child: Focus(
                    autofocus: true,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.escape) {
                        onClose();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TrackerPanelForm(
                      onOpenProject: onOpenProject,
                      onOpenTask: onOpenTask,
                      onDone: onClose,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

---

- [ ] **Step 2: Check the BoxShadow API for `theme.shadows.md`**

The `shadows` token from `context.theme.shadows` returns `BoxShadow` values. Verify the exact type by checking:

```bash
grep -r "shadows" "packages\worklog_studio_style_system\lib" --include="*.dart" -l
```

If `theme.shadows.md` is a `BoxShadow`, wrap it in a list: `boxShadow: [theme.shadows.md]`.
If it is already a `List<BoxShadow>`, use it directly: `boxShadow: theme.shadows.md`.
Adjust the code accordingly.

---

- [ ] **Step 3: Verify compilation**

```bash
cd apps\worklog_studio && fvm flutter analyze lib\feature\time_tracker\presentation\tracker_command_palette.dart
```

Expected: no errors.

---

- [ ] **Step 4: Commit**

```bash
git add apps\worklog_studio\lib\feature\time_tracker\presentation\tracker_command_palette.dart
git commit -m "feat(tracker): add TrackerCommandPalette overlay"
```

---

## Task 3: TrackerChipBar

The compact 36px bar that replaces `TopAppBar`. It manages the `OverlayEntry` lifecycle
for the command palette and dispatches to a bottom sheet on narrow viewports.

**Files:**
- Create: `apps\worklog_studio\lib\feature\time_tracker\presentation\tracker_chip_bar.dart`

**Interfaces:**
- Consumes: `TrackerCommandPalette`, `TrackerPanelCubit`, `TimeTrackerBloc`, `ProjectTaskState`
- Produces: `TrackerChipBar({required ValueChanged<String> onOpenProject, required ValueChanged<String> onOpenTask})`

---

- [ ] **Step 1: Create file with StatefulWidget skeleton and overlay management**

```dart
// apps\worklog_studio\lib\feature\time_tracker\presentation\tracker_chip_bar.dart

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/tracker_panel_cubit.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/active_timer_text.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/tracker_command_palette.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/tracker_panel_form.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class TrackerChipBar extends StatefulWidget {
  final ValueChanged<String> onOpenProject;
  final ValueChanged<String> onOpenTask;

  const TrackerChipBar({
    super.key,
    required this.onOpenProject,
    required this.onOpenTask,
  });

  @override
  State<TrackerChipBar> createState() => _TrackerChipBarState();
}

class _TrackerChipBarState extends State<TrackerChipBar> {
  OverlayEntry? _paletteEntry;

  void _openPalette() {
    if (_paletteEntry != null) return;
    final entry = OverlayEntry(
      builder: (_) => TrackerCommandPalette(
        onClose: _closePalette,
        onOpenProject: widget.onOpenProject,
        onOpenTask: widget.onOpenTask,
      ),
    );
    _paletteEntry = entry;
    Overlay.of(context).insert(entry);
  }

  void _closePalette() {
    _paletteEntry?.remove();
    _paletteEntry?.dispose();
    _paletteEntry = null;
  }

  void _openBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = sheetContext.theme;
        final palette = theme.colorsPalette;
        return Container(
          decoration: BoxDecoration(
            color: palette.background.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.radiuses.lg),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            theme.spacings.xl,
            theme.spacings.md,
            theme.spacings.xl,
            theme.spacings.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: theme.spacings.lg),
                decoration: BoxDecoration(
                  color: palette.background.surfaceMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              TrackerPanelForm(
                onOpenProject: widget.onOpenProject,
                onOpenTask: widget.onOpenTask,
                onDone: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleChipTap() {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 600) {
      _openPalette();
    } else {
      _openBottomSheet();
    }
  }

  @override
  void dispose() {
    _closePalette();
    super.dispose();
  }
```

---

- [ ] **Step 2: Implement build - reads BLoC state and renders chip**

```dart
  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      width: double.infinity,
      height: MediaQuery.sizeOf(context).width >= 600 ? 36 : 40,
      decoration: BoxDecoration(
        color: palette.background.surface,
        border: Border(bottom: BorderSide(color: palette.border.primary)),
      ),
      child: BlocBuilder<TimeTrackerBloc, TimeTrackerBlocState>(
        buildWhen: (prev, curr) =>
            prev.isRunning != curr.isRunning ||
            prev.activeEntryOrNull != curr.activeEntryOrNull,
        builder: (context, state) {
          if (state.isRunning) {
            return _buildRunningChip(context, theme, palette);
          }
          return _buildIdleChip(context, theme, palette);
        },
      ),
    );
  }
```

---

- [ ] **Step 3: Implement _buildIdleChip**

```dart
  Widget _buildIdleChip(
    BuildContext context,
    AppThemeExtension theme,
    dynamic palette,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleChipTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.spacings.x2l),
        child: Row(
          children: [
            WorklogStudioAssets.vectors.playFilled64Svg.svg(
              width: 14,
              height: 14,
              colorFilter: ColorFilter.mode(palette.text.muted, BlendMode.srcIn),
            ),
            SizedBox(width: theme.spacings.sm),
            Text(
              'Start tracking...', // TODO: l10n
              style: theme.commonTextStyles.body.copyWith(
                color: palette.text.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
```

---

- [ ] **Step 4: Implement _buildRunningChip**

```dart
  Widget _buildRunningChip(
    BuildContext context,
    AppThemeExtension theme,
    dynamic palette,
  ) {
    final projectTaskState = context.read<ProjectTaskState>();
    final draftProjectId = context.select<ProjectTaskState, String?>(
      (s) => s.draftProjectId,
    );
    final draftTaskId = context.select<ProjectTaskState, String?>(
      (s) => s.draftTaskId,
    );
    final project = projectTaskState.projects
        .firstWhereOrNull((p) => p.id == draftProjectId);
    final task = projectTaskState.tasks
        .firstWhereOrNull((t) => t.id == draftTaskId);

    final dot = Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacings.sm),
      child: Text(
        '·',
        style: theme.commonTextStyles.body.copyWith(color: palette.text.muted),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleChipTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.spacings.x2l),
        child: Row(
          children: [
            if (project != null) ...[
              WsInitialBadge(
                initials: BadgeUtils.getProjectInitials(project.name),
                backgroundColor: BadgeUtils.getBadgeColor(project.id).$1,
                textColor: BadgeUtils.getBadgeColor(project.id).$2,
                size: WsInitialBadgeSize.small,
              ),
              SizedBox(width: theme.spacings.sm),
              Text(
                project.name,
                style: theme.commonTextStyles.body.copyWith(
                  color: palette.text.secondary,
                ),
              ),
            ],
            if (task != null) ...[
              dot,
              Text(
                task.title,
                style: theme.commonTextStyles.body.copyWith(
                  color: palette.text.secondary,
                ),
              ),
            ],
            dot,
            ActiveTimerText(
              style: theme.commonTextStyles.body.copyWith(
                color: palette.text.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            dot,
            // Stop button - separate GestureDetector so it does not trigger _handleChipTap
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.read<TrackerPanelCubit>().stopTimer(),
              child: WorklogStudioAssets.vectors.squareFilled64Svg.svg(
                width: 14,
                height: 14,
                colorFilter: ColorFilter.mode(
                  palette.accent.danger,
                  BlendMode.srcIn,
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

---

- [ ] **Step 5: Verify compilation**

```bash
cd apps\worklog_studio && fvm flutter analyze lib\feature\time_tracker\presentation\tracker_chip_bar.dart
```

Expected: no errors. Common issues:
- `WorklogStudioAssets.vectors.squareFilled64Svg.svg(...)` - if the SVG asset helper uses a different call pattern, check how `global_time_tracker_panel.dart` used the same assets (it passes them as `leftIcon` to `PrimaryButton`). If `.svg()` is not available as a method, use `SvgPicture.asset(WorklogStudioAssets.vectors.squareFilled64Svg)` with `flutter_svg`.
- `context.read<ProjectTaskState>()` inside `build` - move to local variable at top of `_buildRunningChip`, already done above.

---

- [ ] **Step 6: Commit**

```bash
git add apps\worklog_studio\lib\feature\time_tracker\presentation\tracker_chip_bar.dart
git commit -m "feat(tracker): add TrackerChipBar - compact chip with overlay management"
```

---

## Task 4: Wire up and cleanup

Swap `TopAppBar` to use `TrackerChipBar`. Delete `GlobalTimeTrackerPanel`.

**Files:**
- Modify: `apps\worklog_studio\lib\feature\app\layout\app_bar\top_app_bar.dart`
- Delete: `apps\worklog_studio\lib\feature\time_tracker\presentation\global_time_tracker_panel.dart`

**Interfaces:**
- Consumes: `TrackerChipBar(onOpenProject, onOpenTask)` from Task 3
- Produces: working app with new chip bar visible in place of old expanded panel

---

- [ ] **Step 1: Update top_app_bar.dart**

Replace the entire file content:

```dart
import 'package:flutter/material.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/tracker_chip_bar.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class TopAppBar extends StatelessWidget {
  final ValueChanged<String> onOpenProject;
  final ValueChanged<String> onOpenTask;

  const TopAppBar({
    super.key,
    required this.onOpenProject,
    required this.onOpenTask,
  });

  @override
  Widget build(BuildContext context) {
    return TrackerChipBar(
      onOpenProject: onOpenProject,
      onOpenTask: onOpenTask,
    );
  }
}
```

---

- [ ] **Step 2: Delete GlobalTimeTrackerPanel**

```bash
del "apps\worklog_studio\lib\feature\time_tracker\presentation\global_time_tracker_panel.dart"
```

---

- [ ] **Step 3: Grep for any remaining imports of GlobalTimeTrackerPanel**

```bash
grep -r "global_time_tracker_panel" apps\worklog_studio\lib --include="*.dart"
```

Expected: zero results. If any file still imports it, update that import to `tracker_chip_bar.dart` or remove the import if no longer needed.

---

- [ ] **Step 4: Full analyze**

```bash
cd apps\worklog_studio && fvm flutter analyze
```

Expected: no errors. If there are unused import warnings in `top_app_bar.dart` (e.g. leftover `worklog_studio_style_system` import), remove them.

---

- [ ] **Step 5: Visual check instructions**

The app cannot be launched here (desktop-only; use the dev machine). Confirm:
1. The top bar is visibly thinner (36px) than before.
2. Idle state shows the play icon + "Start tracking..." text in muted color.
3. Clicking the bar opens a centered floating panel with Project / Task / Comment fields + footer.
4. Pressing Esc closes the panel.
5. Clicking the backdrop closes the panel.
6. Selecting a project and task and clicking Start starts the timer and closes the panel.
7. Running state shows the project badge, project name, task name, live timer, and a red square stop icon.
8. Clicking the red stop icon stops the tracker without opening the panel.
9. Clicking anywhere else on the running chip opens the panel.

---

- [ ] **Step 6: Commit**

```bash
git add apps\worklog_studio\lib\feature\app\layout\app_bar\top_app_bar.dart
git commit -m "feat(tracker): wire up TrackerChipBar, remove GlobalTimeTrackerPanel"
```
