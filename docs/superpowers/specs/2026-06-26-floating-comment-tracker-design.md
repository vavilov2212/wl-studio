# Floating Comment Tracker (Global Hotkey Popup) - Design

## Scope

Windows only for this iteration. macOS support (popover + IPC wiring for the new hotkeys) is
deferred until the author has a Mac to test on. The design keeps macOS unaffected and ready for a
follow-up spec.

This spec depends on `2026-06-26-windows-popover-infrastructure-design.md`: it assumes a real
Windows popover window/engine (built via `desktop_multi_window`, opened today by a tray click)
already exists and hosts `MiniPanel`. This spec layers hotkeys, comment editing, and a periodic
reminder on top of that popover - it does not introduce a separate "mini mode main window" hack.

## Problem

The user frequently switches tasks without updating the comment on the currently running time
entry. They want a fast way, independent of which app currently has focus, and even while the
main window is hidden to the tray, to glance at and edit the active entry's comment, switch
task/project, or stop the timer, plus an optional periodic nudge ("are you still working on
this?") so they don't forget to update it.

## Architecture

### Hotkeys

A new `HotkeyService` (`lib/core/services/desktop/hotkey_service.dart`) wraps the
`hotkey_manager` package (pure Dart plugin, no custom native code required) and registers three
global hotkeys at startup, from `WindowsDesktopService.initLeader`:

- **Toggle hotkey** (default `Ctrl+Shift+M`): calls `togglePopover()` - opens the popover and
  focuses the comment field if it's closed, closes it (without saving any in-progress edit) if
  it's already open. This is the single hotkey for "show me the thing."
- **Accept hotkey** (default `Ctrl+Shift+Enter`): saves the current comment (if changed) and
  closes the popover.
- **Dismiss hotkey** (default `Ctrl+Shift+Escape`): closes the popover without saving any edit in
  progress, leaving the comment as it was.

All three are global hotkeys (not just widget-level shortcuts), so accept/dismiss work even if
the popover window didn't grab OS focus. They're configurable from Settings (see below) and stay
registered for as long as the process is alive (i.e., while running in the tray, not after a full
quit, which is acceptable).

### Popover reuse

`showPopover()`/`hidePopover()`/`togglePopover()` call straight into the Windows popover
infrastructure from the companion spec (create-if-needed, position near tray, show/hide, keep the
engine warm between opens). No window-state snapshotting/restoring is needed since the popover is
a distinct window from the main one.

### Shared mini-tracker UI

`MiniPanel` (`lib/feature/desktop/presentation/mini_panel.dart`) gains an inline comment editor
on the active-session card, following the existing `InlineField`/`TextArea` pattern from
`time_entry_drawer.dart` (edits call `_service.updateActive(comment: text)` /
`TimeTrackerEntryUpdated`). The project/task switcher and recent-activity list already exist in
`MiniPanel` and need no changes. Because this is plain shared Flutter code, it will render
correctly inside the macOS popover once that platform's hotkey/IPC wiring is added later.

The comment field tracks unsaved edits locally; accept commits them, dismiss (or toggle-close)
discards them and reverts the field to the persisted comment.

### Periodic reminder

A new `ReminderService` (`lib/core/services/reminder_service.dart`), pure Dart, runs a
`Timer.periodic` at the configured interval, active only while a time entry is running. On fire,
it invokes the same `showPopover()` path as the toggle hotkey, pre-focused on the comment field.
If untouched for about 20 seconds it auto-closes (discarding any unsaved edit, same as dismiss);
the running timer is never auto-paused.

### Settings persistence

No settings persistence layer exists today (`settings_screen.dart` is stateless UI only). Add an
`app_settings` key-value table to the existing SQLite database, using the same migration approach
as `time_entries`, plus a `SettingsRepository` (`getString`/`setString` or typed helpers). New
keys:

- `reminder_interval_minutes` (off / 1 / 2 / 5 / 10 / 30)
- `toggle_hotkey`, `accept_hotkey`, `dismiss_hotkey` (each a serialized `HotKey`)

`settings_screen.dart` gets a new section built from existing design-system components (interval
picker, three hotkey recorders). No new design-system primitives required.

### Data flow

`TimeTrackerBloc` (leader) remains the single source of truth. The popover engine reads it via the
multi-window IPC channel from the companion spec (`TimerSnapshot`/`TimerAction`), exactly as
`MiniPanel` already does today for start/stop/task-switch. Comment edits dispatch through the same
channel as a new `TimerAction` variant (`updateComment`), so no new persistence path is
introduced.

## Out of scope (this iteration)

- macOS popover/IPC wiring for the new hotkeys and reminder (deferred to a follow-up spec once
  testable).
- Hotkey customization UI beyond recording the three defaults described above.
- Auto-pausing the timer if the reminder is repeatedly ignored (explicitly rejected, nudge only).

## Testing

- `HotkeyService` and `ReminderService`: unit tests under `test/core/` using fakes for the hotkey
  channel and a fake/controllable timer, per the mandatory TDD rule in
  `apps/worklog_studio/CLAUDE.md`.
- `SettingsRepository`: unit test under `test/core/` against an in-memory SQLite DB, mirroring the
  existing repository test pattern.
- The new `updateComment` `TimerAction` round-trip (follower dispatches, leader applies, snapshot
  reflects it back) gets a unit test under `test/feature/`, mirroring how start/stop actions are
  tested today.
- Hotkey-to-popover-to-accept/dismiss end-to-end behavior is OS-level orchestration, exempt from
  the mandatory test rule, but should be manually verified on Windows: toggle open/closed, edit
  comment and accept, edit comment and dismiss (reverts), reminder auto-dismiss after ~20s.
