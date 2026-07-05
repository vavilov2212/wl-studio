# Windows Native Popover Infrastructure - Design

## Scope

Bring Windows to functional parity with the existing macOS tray-click mini panel: a real
secondary always-on-top window/engine hosting `MiniPanel`, opened from the tray icon, with the
same search/start/stop/task-switch behavior macOS already has. This spec covers only the
infrastructure (window + IPC), no global hotkeys, no comment editing, no reminders. Those are
layered on top by the companion spec
(`2026-06-26-floating-comment-tracker-design.md`), which depends on this one.

## Why this is separate

Today `WindowsDesktopService` no-ops every popover method (`showPopover`, `hidePopover`,
`togglePopover`, `initFollower`); Windows has never had a second window. macOS's version of this
(`PopoverPanel.swift` / `IpcRouter.swift`, a hand-written second `FlutterEngine` in a custom
borderless `NSPanel`) is substantial native Swift code. Reproducing that exactly in native Win32
C++ would be a large, separate effort. Instead we get the same functional result, a real separate
floating window rather than a disguised main window, using the `desktop_multi_window` Flutter
plugin, which already implements multi-engine/multi-window support on Windows and ships its own
inter-window method channel. This avoids hand-written native code while still giving a real
second engine/window, matching the architectural shape (not the literal implementation) of the
macOS side.

## Architecture

### Package

Add `desktop_multi_window` to `apps/worklog_studio/pubspec.yaml`. It provides:
- `DesktopMultiWindow.createWindow(args)`: spawns a new isolated Flutter window/engine, returns
  a `WindowController`.
- `windowController.setFrame(...)`, `.show()`, `.hide()`, `.center()`: used to size/position the
  popover near the tray icon and keep it borderless/always-on-top (combined with the window's own
  `window_manager`-style flags set from inside the secondary engine's `main()`).
- A built-in `invokeMethod`/`setMethodCallHandler` channel between the main window and each
  sub-window. This is the IPC layer, replacing the hand-rolled `MethodChannel('worklog_studio/ipc')`
  that macOS uses natively, but with the same role: broadcast `TimerSnapshot`, receive
  `TimerAction`.

### Entry point branching

`main.dart` currently has a single entry point. With `desktop_multi_window`, the popover window
runs the same Dart executable but is launched with a special argument that the plugin passes to a
secondary `main()` invocation. Mirror the existing `resolveStartupRole()` concept
(`IDesktopPlatformService.resolveStartupRole()`, currently macOS-only, returns `'main'` or
`'popover'`): on Windows, detect the multi-window sub-window arguments at startup and route to a
minimal `runApp` that mounts `MiniPanel` wrapped in a `MiniTrackerCubit`, instead of the full app
shell.

### WindowsDesktopService becomes a real implementation

`initLeader`: in addition to today's `WindowsTrayService().init(...)`, start listening for
`tray_manager` left-click and call `showPopover()`.

`showPopover()`: if the sub-window doesn't exist yet, create it via
`DesktopMultiWindow.createWindow` sized roughly 360x520, frameless, positioned above the tray icon
(tray icon screen bounds are already available via `tray_manager`), then `.show()`. If it already
exists, just reposition and `.show()`.

`hidePopover()`: `.hide()` the sub-window without destroying it, keeping state warm, same as how
macOS keeps its popover engine alive.

`initFollower(cubit)`: called from the secondary entry point's `main()`; subscribes to the
multi-window IPC channel and feeds incoming `TimerSnapshot` broadcasts into the
`MiniTrackerCubit`, mirroring `MacOSDesktopService.initFollower`.

`dispatchAction(action)`: from the follower side, sends `TimerAction` (start/stop/comment update)
back to the main window's `TimeTrackerBloc` over the same channel, mirroring
`MacOSDesktopService.dispatchAction`.

### Shared code, no duplication

`TimerAction`/`TimerSnapshot` (`lib/feature/desktop/ipc/ipc_models.dart`) and `MiniTrackerCubit`
are already platform-agnostic and need no changes; only the transport (multi-window channel
instead of native `MethodChannel`) differs from macOS. `MiniPanel` itself needs no changes for
this spec (comment editing is added by the companion spec, on top of whichever popover
infrastructure is active).

## Out of scope

- Global hotkeys, comment editing in the popover, periodic reminders: see the companion spec.
- macOS changes: none.
- Visual/positioning polish beyond "appears near the tray icon, doesn't overlap the taskbar."

## Testing

- `WindowsDesktopService`'s IPC message handling (an equivalent of
  `_handleIncomingIpcMessage`) gets a unit test under `test/core/` using a fake channel,
  mirroring how `MacOSDesktopService` would be tested.
- The actual window creation/positioning is OS-level orchestration, exempt from the mandatory
  test rule, verified manually: tray click opens the popover, search/start/stop/task-switch all
  work, hide-on-blur or explicit close keeps the engine warm for next open.
