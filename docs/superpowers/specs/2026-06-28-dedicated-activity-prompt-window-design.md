# Dedicated Activity Prompt Window - Design

## Scope

Windows only, same as the floating-comment-tracker work this builds on. macOS is unaffected.

This spec depends on the already-shipped Windows popover infrastructure (`desktop_multi_window`-based
secondary engine hosting `MiniPanel`) and the floating-comment-tracker work (global hotkeys, the
reminder, the leader/follower IPC channel, `MiniTrackerCubit`'s `commands` stream and
`MiniPanelCommand` enum). It does not redesign any of that - it generalizes the *single secondary
window* those pieces assumed into *two independently-existing* secondary windows.

## Problem

Reference: TopTracker (by HireGlobal) shows two coexisting floating windows - a tray-anchored
"Tracking Right Now" widget (their equivalent of our `MiniPanel`), and a separate, small, fixed-position
"Current Activity Description" prompt (a single text field, "Enter to submit, Esc to dismiss") that
appears independently when a reminder fires, a hotkey is pressed, or a button in the tracker widget is
clicked. Both can be on screen at once.

Today, our hotkeys (toggle/accept/dismiss) and the reminder all target `MiniPanel` itself - opening,
focusing, and closing the *same* window the tray icon opens. There is no separate, minimal,
always-available "what are you working on" prompt. The user wants that second window type, matching
the reference product, with the two windows able to coexist.

## Architecture

### Two managed windows, one shared abstraction

`WindowsDesktopService` currently tracks exactly one secondary window's lifecycle inline: a single
`_popoverWindowId`, `_isPopoverVisible`, `_followerReady`, a `_creationInFlight` completer for
serialized creation, and a 1-second prewarm watchdog. All of that logic was hard-won (a window-creation
race, a broken liveness probe, a watchdog that silently disabled itself) and must not be duplicated by
hand for a second window.

That state and its methods move into a small private class, `_ManagedPopoverWindow`, parameterized by
a `computeFrame` function:

```dart
class _ManagedPopoverWindow {
  _ManagedPopoverWindow({required this.role, required this.computeFrame});

  final String role; // 'miniPanel' | 'activity' - passed through createWindow()'s payload
  final Future<Rect> Function() computeFrame;

  int? windowId;
  bool isVisible = false;
  bool followerReady = false;
  Future<void>? creationInFlight;

  // ensureExists(), isAlive() (targeted liveness ping), show(), hide(),
  // reconcile() - the exact logic already built and fixed for the single
  // popover case, now methods on this class instead of inline fields/methods
  // on WindowsDesktopService.
}
```

`WindowsDesktopService` holds two instances:

```dart
final _miniPanelWindow = _ManagedPopoverWindow(role: 'miniPanel', computeFrame: _computeMiniPanelFrame);
final _activityWindow = _ManagedPopoverWindow(role: 'activity', computeFrame: _computeActivityFrame);
```

The 1-second prewarm watchdog iterates both instances each tick instead of checking one. Both get the
same race-free creation serialization and the same targeted-ping liveness detection (the
`PlatformException(code: '-1', message: 'target window not found.')` signal), applied uniformly.

### Follower role detection

`desktop_multi_window`'s `createWindow(arguments)` already threads a payload string through to the new
engine's `main(args)` as `args[2]`. Window creation now passes a role marker:

```dart
await DesktopMultiWindow.createWindow(jsonEncode({'role': managedWindow.role}));
```

`resolveStartupRole(args)` (already responsible for distinguishing `'main'` vs `'tray'` via `args[0]`/
`args[1]`) is extended to also parse `args[2]`'s `role` field, exposing it (e.g.
`followerRoleForTesting`) so `runner.dart` can pick the right top-level widget:

- `role == 'main'` -> `MainApp()` (unchanged)
- `role == 'tray'` and follower role `'miniPanel'` -> `MiniApp()` (unchanged, shows `MiniPanel`)
- `role == 'tray'` and follower role `'activity'` -> new `ActivityPromptApp()` (shows
  `ActivityPromptPanel`)

Both follower apps construct a `MiniTrackerCubit` the same way `MiniApp` does today via
`WindowsDesktopService.initFollower(cubit)` - no duplicated snapshot-subscription logic, just two
different widget trees consuming the same cubit type.

### Activity window UI

New widget `ActivityPromptPanel`, hosted by new `ActivityPromptApp`, parallel to
`MiniPanel`/`MiniApp` but much smaller: a single text field bound to the active entry's comment
(read from the same `MiniTrackerCubit` snapshot state `MiniPanel` already uses), autofocused on open,
with a hint matching the reference ("Enter to submit, Esc to dismiss"). No project/task picker, no
recent-activity list, no search - comment-only.

It subscribes to the same `MiniTrackerCubit.commands` stream and handles the same
`MiniPanelCommand` values `MiniPanel` already handles (`focusComment`, `acceptComment`,
`dismissComment`, `autoDismissComment`) with identical commit/discard semantics - submitting dispatches
`updateComment` over the existing `TimerAction`/`dispatchAction` IPC channel exactly like `MiniPanel`'s
inline editor does today; dismissing reverts to the last persisted comment.

Window size is small and fixed (e.g. 420x100 logical pixels), not resizable - no need for the mini
panel's 360x520 budget.

### Activity window positioning

A new pure function, `computeActivityPromptFrame({required Size screenSize, required Size
promptSize, double topMargin = 96})`, mirroring `computePopoverFrame`'s style: horizontally centered
on the screen, a fixed distance from the top edge. No tray bounds, no live queries, no anchor-icon
math at all - this sidesteps everything fought through for the mini panel's positioning. Still passed
through the existing `clampFrameToScreen` as a final guarantee, though a fixed, screen-size-derived
position should never need clamping in practice.

### Hotkey, reminder, and button rewiring

- **Toggle hotkey**: opens/closes the **activity window** (`_activityWindow`) instead of the mini
  panel. The mini panel becomes tray-click-only. If nothing is currently being tracked, the toggle
  hotkey is a no-op - it never opens an activity window with nothing to comment on.
- **Accept hotkey**: commits the activity window's edit and closes it (was: the mini panel's). The
  commit only has an effect if a session is currently running - this guard already exists today in
  `_handleFollowerAction`'s `updateComment` branch and carries over unchanged, just now reached via
  the activity window's dispatch instead of the mini panel's.
- **Dismiss hotkey**: discards and closes the activity window (was: the mini panel's).
- **Reminder timer**: `ReminderService.onFire` now opens the **activity window**
  (`showActivityPromptNearScreenCenter()`-equivalent) instead of the mini panel, and focuses its text
  field. The existing `isPopoverOpen` guard (skip firing if already open, added so the reminder
  wouldn't interrupt a window the user already has open) now checks the **activity window's**
  visibility specifically - the mini panel being open no longer suppresses the reminder, since the
  reminder's job is now entirely about the activity prompt, not the mini panel.
- **New button inside `MiniPanel`**: opens the activity window manually (mirroring the reference's
  "Switch Activity" link), independent of the hotkeys.
- The mini panel's existing inline comment editor (built in the floating-comment-tracker work) is kept
  as-is, per explicit decision - editing the comment is now possible three ways (inline in the mini
  panel directly, or via the activity window through hotkey/reminder/button), all writing through the
  same `updateComment` dispatch, so they can never disagree about what's persisted.

### IPC addressing

`requestFocusComment()`/`acceptCurrentComment()`/`dismissCurrentComment()`/
`autoDismissCurrentComment()` become parameterized by which `_ManagedPopoverWindow` to target, rather
than implicitly operating on the single previous `_popoverWindowId`. The existing
`_handleIncomingIpcMessage` switch (which dispatches by method name to `_followerCubit?.emitCommand`)
needs the leader to track readiness and the snapshot-broadcast target **per window** rather than via
the single `_followerReady`/`_followerCubit` fields used today - each `_ManagedPopoverWindow` carries
its own `followerReady` flag and, on the follower side, each engine has exactly one
`MiniTrackerCubit`/`_followerCubit`, so this is a matter of looking up the right managed window by
`fromWindowId` when routing an incoming message, not a deep redesign.

## Out of scope (this iteration)

- macOS equivalent of the activity window (macOS popover work is already deferred per the earlier
  floating-comment-tracker spec).
- Project/task switching inside the activity window (comment-only, per explicit decision).
- Any settings/gear affordance on the activity window itself (the reference product's gear icon is
  out of scope - app settings already live in the main window's Settings page).
- Resizing or repositioning the activity window by the user (fixed position and size).

## Testing

- `_ManagedPopoverWindow`'s reconcile/creation-serialization logic is exercised the same way the
  single-window case already is, via the existing `windows_desktop_service_ipc_test.dart` test seams
  (`setFollowerCubitForTesting`, `handleIncomingIpcMessageForTesting`), extended to confirm IPC
  commands route to the *correct* window's cubit when two are tracked, not just *a* cubit.
- `computeActivityPromptFrame` gets the same kind of unit test `computePopoverFrame`/
  `clampFrameToScreen` already have in `popover_positioning_test.dart` - pure, deterministic, no
  native dependencies.
- `ActivityPromptApp`/`ActivityPromptPanel` are UI-only and exempt from the mandatory-test rule, same
  as `MiniPanel` today - verified by static analysis and manual testing.
- Hotkey/reminder rewiring (which window each trigger targets) has no new pure logic beyond what
  `HotkeyService`/`ReminderService` already have tested - the wiring itself in
  `windows_desktop_service.dart`'s `initLeader` is real native orchestration, exempt, same as today.
- Manual verification checklist (Windows-only, on the user): toggle/accept/dismiss hotkeys open/
  commit/discard the activity window; the reminder opens the activity window (not the mini panel), and
  having the mini panel open does not suppress the reminder; the new mini-panel button opens the
  activity window; both windows can be open at the same time without interfering with each other's
  state (e.g. editing the comment in one is reflected correctly when the other is later opened).
