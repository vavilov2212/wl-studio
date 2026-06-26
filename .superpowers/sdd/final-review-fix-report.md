# Final Review Fix Report

File: `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`

## Finding 1: `showPopover()` unguarded against platform-call failures

Wrapped the body of `showPopover()` in a try/catch, matching the `debugPrint('WindowsDesktopService: ... - $e')` pattern used by every other method in the file. `_isPopoverVisible = true` now only executes after `createWindow`/`setFrame`/`show` (or `setFrame`/`show` on the reuse path) all complete successfully. On failure, the error is logged via `debugPrint`, and if the window was newly created during this call (tracked via a `wasNewWindow` flag captured before the try block), `_popoverWindowId` is reset to `null` so a subsequent call creates a fresh window rather than reusing a possibly-broken one. `_isPopoverVisible` is never set to `true` inside the catch path, so it remains `false` (or whatever it already was) on failure.

## Finding 2: Windows never sets `_followerReady = false` on hide, so the leader keeps broadcasting to a hidden popover

`hidePopover()` runs entirely in the leader process (it owns and operates on `_popoverWindowId`). After the existing `.hide()` call succeeds inside the try block, the method now also sets `_followerReady = false` directly - no IPC round-trip needed, since `_followerReady` already lives in this same leader-side instance. This stops `_broadcastSnapshotIfReady` (gated on `_followerReady`) from sending wasted IPC calls to a hidden window, achieving the same practical effect as macOS's follower-initiated `miniClosed` message without a fake self-directed IPC call.

## Verification

### `fvm flutter analyze lib/core/services/desktop/windows_desktop_service.dart`

```
Analyzing windows_desktop_service.dart...
No issues found! (ran in 16.8s)
```

### `fvm flutter test test/core/ test/feature/ --reporter expanded`

```
01:02 +137: All tests passed!
```

137/137 tests passed, including `test/core/windows_desktop_service_ipc_test.dart` and `test/core/windows_desktop_service_test.dart`.
