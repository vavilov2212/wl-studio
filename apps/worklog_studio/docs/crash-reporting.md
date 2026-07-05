# Crash Reporting

## How it works

`windows/runner/main.cpp` registers `SetUnhandledExceptionFilter` before any
Flutter or Dart code runs. When the process crashes at the native level (an
access violation inside `flutter_windows.dll`, for example), Windows calls the
handler before terminating. The handler writes two files:

| File | Contents |
|---|---|
| `crash_YYYYMMDD_HHMMSS.dmp` | Full minidump - open in WinDbg for a native call stack |
| `crash_YYYYMMDD_HHMMSS.txt` | Timestamp, exception code, exception address - readable without a debugger |

Files land in:
```
%LOCALAPPDATA%\WorklogStudio\crashes\
```

The Dart-level crash logger (`lib/core/services/crash_logger.dart`) handles
thrown Dart exceptions separately and writes to `%LOCALAPPDATA%\WorklogStudio\crash.log`.
Native crashes bypass Dart entirely, which is why only the C++ handler can
catch them.

---

## Reading a crash dump

### Option A - Visual Studio (recommended if already installed)

1. File > Open > File > select the `.dmp` file.
2. VS shows a **Minidump Summary** page with the exception code and faulting module.
3. Click **"Debug with Native Only"** in the Actions section.
4. VS loads the dump as a frozen debug session - full call stack in the Call Stack
   window, locals, and register values.

**Loading Flutter symbols in Visual Studio:**
Tools > Options > Debugging > Symbols - add a symbol server entry:
```
https://storage.googleapis.com/flutter_infra_release/flutter/<ENGINE_HASH>/windows-x64/symbols
```
Replace `<ENGINE_HASH>` with the engine hash from `flutter --version` (the `Engine` line).
VS downloads and caches the `.pdb` for `flutter_windows.dll` on first use.

VS also needs the original `flutter_windows.dll` binary to match against the dump.
If it prompts, point it to the release folder that crashed
(e.g. `Downloads\worklog_studio_windows_1.0.11-dev.10\`).

### Option B - WinDbg Preview (no Visual Studio required)

Download from the Microsoft Store (free).

1. File > Open dump file > select the `.dmp` file.
2. Wait for it to load, then run in the command box:
   ```
   !analyze -v
   ```

`!analyze -v` prints a `STACK_TEXT` section - every frame on the crashing
thread. Useful follow-up commands:

```
k          - raw call stack
~*k        - stack for every thread (useful for race conditions)
lmvm flutter_windows  - module version and timestamp
```

**Loading Flutter symbols in WinDbg:**
File > Settings > Debugging settings > Symbol path, add:
```
srv*C:\symbols*https://storage.googleapis.com/flutter_infra_release/flutter/<ENGINE_HASH>/windows-x64/symbols
```
Then run `.reload` followed by `!analyze -v` again.

---

## Sending crash info for investigation

If you cannot run WinDbg yourself, share:

1. The `.dmp` file.
2. The matching `.txt` sidecar.
3. The output of `flutter --version` so the engine hash is known.

---

## Upgrade path - crash reporting for real users

The current implementation captures crashes locally. When ready to collect
crashes from end users, the same `WriteCrashDump` handler is the integration
point. Two options:

### Sentry

Sentry has a native Windows SDK (`sentry-native`) that uploads minidumps
automatically. Integration is roughly:

1. Add `sentry_flutter` to `pubspec.yaml` for Dart-level exception capture.
2. Initialize the native Sentry SDK from `main.cpp` before
   `SetUnhandledExceptionFilter`, passing your DSN.
3. Remove (or keep alongside) the local file write.

The Dart SDK and the native SDK report to the same Sentry project, so you get
both Dart exceptions and native crashes in one place.

### BugSplat

BugSplat is purpose-built for native desktop crash dumps. It accepts
`MiniDumpWriteDump` output directly and has a Flutter plugin. Better tooling
for analyzing `flutter_windows.dll` crashes than Sentry's generic diff view.

Both options require only modifying `WriteCrashDump` in `main.cpp` - no
structural changes to the rest of the app.
