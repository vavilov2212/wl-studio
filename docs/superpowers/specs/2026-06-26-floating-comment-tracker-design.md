# Floating Comment Tracker (Global Hotkey Popup) — Design

## Scope

Windows only for this iteration. macOS support (popover + IPC wiring) is deferred until the
author has a Mac to test on. The design keeps macOS unaffected and ready for a follow-up spec.

## Problem

The user frequently switches tasks without updating the comment on the currently running time
entry. They want a fast way — independent of which app currently has focus, and even while the
main window is hidden to the tray — to glance at and edit the active entry's comment, switch
task/project, or stop the timer, plus an optional periodic nudge ("are you still working on
this?") so they don't forget to update it.

## Architecture

### Hotkeys

A new `HotkeyService` (`lib/core/services/desktop/hotkey_service.dart`) wraps the
`hotkey_manager` package (pure Dart plugin, no custom native code required on Windows) and
registers two global hotkeys at startup, from `WindowsDesktopService.initLeader`:

- **Open hotkey** (default `Ctrl+Shift+M`): calls `showPopover()` and focuses the comment field.
- **Accept hotkey** (default `Ctrl+Shift+Enter`): saves the current comment and calls
  `hidePopover()`. Registered as a *global* hotkey (not just a widget-level shortcut) so it works
  even if the popup didn't grab OS focus.

Both hotkeys are configurable from Settings (see below) and stay registered for as long as the
process is alive (i.e., while running in the tray — not after a full quit, which is acceptable).

### Windows "mini mode" popup

Windows has no multi-window/native popover infrastructure today (`WindowsDesktopService` no-ops
all `IDesktopPlatformService` popover methods). Rather than build one, `showPopover()`/
`hidePopover()` repurpose the existing main window:

1. On open: snapshot current window size/position/route, call `window_manager`'s
   `setAsFrameless()`, `setSize(360, 520)`, `setAlwaysOnTop(true)`, reposition near the cursor or
   tray icon, and swap the displayed route to the mini-tracker view.
2. On close (via accept hotkey, Esc, or losing focus): restore the previous frame/size/position
   and route.

This is Dart-only — no changes to `windows/runner/*`.

### Shared mini-tracker UI

`MiniPanel` (`lib/feature/desktop/presentation/mini_panel.dart`) gains an inline comment editor
on the active-session card, following the existing `InlineField`/`TextArea` pattern from
`time_entry_drawer.dart` (edits call `_service.updateActive(comment: text)` /
`TimeTrackerEntryUpdated`). The project/task switcher and recent-activity list already exist in
`MiniPanel` and need no changes. Because this is plain shared Flutter code, it will render
correctly inside the macOS popover once that platform is wired up later — only the macOS-side
hotkey/IPC trigger is deferred, not the UI.

### Periodic reminder

A new `ReminderService` (`lib/core/services/reminder_service.dart`), pure Dart, runs a
`Timer.periodic` at the configured interval, active only while a time entry is running. On fire,
it invokes the same `showPopover()` path as the open hotkey, pre-focused on the comment field. If
untouched for ~20 seconds it auto-closes and restores the previous window state; the running
timer is never auto-paused.

### Settings persistence

No settings persistence layer exists today (`settings_screen.dart` is stateless UI only). Add an
`app_settings` key-value table to the existing SQLite database, using the same migration approach
as `time_entries`, plus a `SettingsRepository` (`getString`/`setString` or typed helpers). New
keys:

- `reminder_interval_minutes` (off / 1 / 2 / 5 / 10 / 30)
- `open_hotkey` (serialized `HotKey`)
- `accept_hotkey` (serialized `HotKey`)

`settings_screen.dart` gets a new section built from existing design-system components (interval
picker, two hotkey recorders) — no new design-system primitives required.

### Data flow

`TimeTrackerBloc` remains the single source of truth; mini mode reads it directly (no IPC needed
since it's the same engine/window). Comment edits and task/project switches dispatch through the
existing `TimeTrackerBloc` events used by `MiniPanel` today — no new persistence path.

## Out of scope (this iteration)

- macOS popover/IPC wiring for the new hotkeys and reminder (deferred to a follow-up spec once
  testable).
- Per-OS hotkey customization beyond the two defaults described above is supported via settings,
  but no UI for *adding more than two* hotkeys.
- Auto-pausing the timer if the reminder is repeatedly ignored (explicitly rejected — nudge only).

## Testing

- `HotkeyService` and `ReminderService`: unit tests under `test/core/` using fakes for the hotkey
  channel and a fake/controllable timer, per the mandatory TDD rule in
  `apps/worklog_studio/CLAUDE.md`.
- `SettingsRepository`: unit test under `test/core/` against an in-memory SQLite DB, mirroring the
  existing repository test pattern.
- Mini-mode window transition (frameless/resize/reposition/restore) is UI/window-manager
  orchestration — exempt from the mandatory test rule, but should be manually verified on Windows
  (open via hotkey, edit comment, switch task, accept-close, reminder auto-dismiss).
