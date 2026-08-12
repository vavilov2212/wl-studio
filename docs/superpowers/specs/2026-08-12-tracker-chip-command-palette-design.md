# Tracker Chip + Command Palette - Design Spec

**Date:** 2026-08-12
**Status:** Approved

---

## 1. Goal

Replace the always-expanded `TopAppBar` tracker panel with a minimal persistent chip bar
(36px tall) that keeps the tracker state visible at all times while freeing the full
viewport height for page content. Full tracker controls open on demand via a command-palette
style floating overlay (desktop) or a bottom sheet (mobile/small viewports).

This is the first step toward a more professional, intentional UI - removing visual noise
and giving every element a clear purpose.

---

## 2. Current Architecture

```
AppShell
  Row
    SidebarNavigation
    Column
      TopAppBar          <- full-width white bar, ~56px, always shows all fields
        GlobalTimeTrackerPanel
          InlineField(Project)
          InlineField(Task)
          InlineField(Comment)
          ActiveTimerText
          PrimaryButton (start/stop)
      content area
```

**Problems:**
- Permanently consumes ~56px of vertical space on every screen.
- Fields are always visible even when not needed.
- Bar feels like browser chrome, not a purposeful UI element.

---

## 3. New Architecture

```
AppShell
  Row
    SidebarNavigation
    Column
      TrackerChipBar     <- NEW: full-width, 36px, compact state only
      content area

  TrackerCommandPalette  <- NEW: Overlay widget, shown on demand (desktop)
```

### 3.1 TrackerChipBar

Located where `TopAppBar` is today. Same `background.surface` fill and
`border.bottom = border.primary` (1px). Height: **36px**.

#### Idle state

```
[ > Start tracking... ]
```

- Small play icon (`playFilled64Svg`, 14px) in `text.muted`
- Text "Start tracking..." in `text.muted`, `commonTextStyles.body`
- Left-padded `spacings.x2l` (32px) to align with page content
- Entire bar is a single tap target - opens the overlay/sheet

#### Running state

```
[ [SP] Side project · WS App · 00:14:22 · [■] ]
```

- `[SP]` - `WsInitialBadge` size `small` (existing component)
- Project name - `text.secondary`, `commonTextStyles.body`
- `·` separator - `text.muted`
- Task name - `text.secondary`, `commonTextStyles.body`
- `·` separator - `text.muted`
- Timer `00:14:22` - `text.primary`, `commonTextStyles.body`,
  `FontFeature.tabularFigures()` (monospace rhythm)
- `[■]` stop button - `squareFilled64Svg`, 14px icon, `accent.danger` tint,
  **tapping this stops the tracker immediately without opening the overlay**
- Tapping anywhere else on the bar opens the overlay

Elements are left-aligned, vertically centered. Separator dots have `spacings.sm`
horizontal padding on each side.

---

### 3.2 TrackerCommandPalette (desktop, width >= 600px)

A floating panel rendered via Flutter `Overlay`. Opens when the chip bar is tapped
(anywhere except the stop button).

#### Visual spec

- **Width:** 520px fixed
- **Position:** centered horizontally; top edge at 18% of screen height
- **Background:** `background.surface`
- **Border:** `border.primary`, 1px, all sides
- **Border-radius:** `radiuses.lg` (16px)
- **Shadow:** `context.theme.shadows` (medium elevation)
- **Padding:** `spacings.xl` (24px) on all sides
- **Backdrop:** full-screen `ModalBarrier`, color `rgba(0,0,0,0.12)`

#### Layout

```
Label: Project
[Select field - full width]

Label: Task
[Select field - full width]

Label: Comment
[Text input - full width]

---- divider (border.primary) ----

00:00:00 (timer, left)            [ Start > ] (button, right)
```

- Field labels: `commonTextStyles.label` in `text.secondary`
- `spacings.md` (12px) gap between label and field
- `spacings.lg` (16px) gap between each field group
- `spacings.lg` above the footer divider
- `spacings.lg` below the footer divider

Footer row:
- Left: `ActiveTimerText` using `commonTextStyles.h2` style,
  color `text.primary` when running / `text.muted` when idle
- Right: `PrimaryButton` - label "Start" + play icon (idle) or
  `type: danger` + "Stop" + square icon (running)
- Pressing Start: calls `cubit.startTimer()`, then closes the overlay
- Pressing Stop: calls `cubit.stopTimer()`, then closes the overlay

#### Keyboard behavior

| Key | Action |
|-----|--------|
| `Esc` | Close overlay without changes |
| `Tab` / `Shift+Tab` | Cycle between Project, Task, Comment, button |
| `Enter` on button | Start or stop |

Click on backdrop closes without changes.

#### Overlay lifecycle

- Opened: `Overlay.of(context).insert(OverlayEntry(...))`
- Closed: on backdrop tap, Esc, or after start/stop action
- Only one instance can exist at a time

---

### 3.3 Mobile / bottom sheet (width < 600px)

Same `TrackerChipBar` (height: 40px on mobile for larger touch targets).

Tapping chip opens a `showModalBottomSheet`:

- `isScrollControlled: true` (content-height sheet)
- `backgroundColor: background.surface`
- `shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: radiuses.lg))`
- Drag handle at top center (4px x 40px pill, `background.surfaceMuted`)
- Same field layout as desktop overlay (Project / Task / Comment / footer)
- Closes on swipe-down or backdrop tap

In landscape on mobile (width >= 600px but running on a mobile device), the desktop
overlay behavior applies.

---

## 4. Responsive breakpoints

| Viewport width | Chip height | Expansion behavior |
|----------------|-------------|-------------------|
| >= 600px | 36px | Command palette overlay (centered) |
| < 600px | 40px | Modal bottom sheet |

---

## 5. Reuse of existing components

No existing form components are rebuilt. The overlay/sheet reuses:
- `InlineField` + `InlineFieldController` for Project, Task, Comment
- `Select<String>` with all existing options/action builders
- `PrimaryInput` for Comment
- `ActiveTimerText` for timer display
- `PrimaryButton` for start/stop
- `WsInitialBadge` for project/task badges in the chip

A new `TrackerPanelForm` widget is extracted from `GlobalTimeTrackerPanel`,
containing only the field layout (Project / Task / Comment + footer row).
`GlobalTimeTrackerPanel` is deleted; `TrackerPanelForm` is used inside both
`TrackerCommandPalette` and the mobile bottom sheet builder.

---

## 6. Files affected

| File | Change |
|------|--------|
| `feature/app/layout/app_bar/top_app_bar.dart` | Replace content with `TrackerChipBar` |
| `feature/time_tracker/presentation/global_time_tracker_panel.dart` | Deleted - replaced by `TrackerPanelForm` |
| `feature/time_tracker/presentation/tracker_panel_form.dart` | NEW - form fields extracted from GlobalTimeTrackerPanel |
| `feature/time_tracker/presentation/tracker_chip_bar.dart` | NEW - chip widget |
| `feature/time_tracker/presentation/tracker_command_palette.dart` | NEW - overlay widget (desktop) |
| `feature/app/layout/app_shell.dart` | No structural change needed |

---

## 7. Out of scope

- Dark mode styling (tokens already defined, no extra work)
- Keyboard shortcut to open the palette (hotkeys feature is separate)
- Animation/transition polish beyond default Flutter overlay behavior
- Any change to tracker business logic (BLoC, services unchanged)
