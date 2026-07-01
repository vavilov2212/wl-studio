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

### Install WinDbg

Download **WinDbg Preview** from the Microsoft Store (free). It is the
standard tool for reading Windows minidumps.

### Open the dump

1. Launch WinDbg Preview.
2. File > Open dump file > select the `.dmp` file.
3. Wait for it to finish loading (it will say `Loading unloaded module list...`).
4. In the command box at the bottom, run:
   ```
   !analyze -v
   ```

### What to look for

`!analyze -v` prints a section called `STACK_TEXT`. It lists every frame on
the crashing thread's call stack at the moment of the crash. Even without full
symbols you will see which function inside `flutter_windows.dll` faulted and
what called it.

Useful follow-up commands:

```
k          - print the raw call stack
~*k        - print the stack for every thread (useful for race conditions)
lmvm flutter_windows  - show the module version and timestamp
```

### Loading Flutter symbols (optional but helpful)

The Flutter engine publishes symbol files to a public symbol server. Add it
in WinDbg to get readable function names instead of raw offsets:

1. File > Settings > Debugging settings > Symbol path.
2. Add:
   ```
   srv*C:\symbols*https://storage.googleapis.com/flutter_infra_release/flutter/<ENGINE_HASH>/windows-x64/symbols
   ```
   Replace `<ENGINE_HASH>` with the engine hash from `flutter --version`
   (the `Engine` line, e.g. `c108a94d7a8273e112339e6c6833daa06e723a54`).
3. Run `.reload` then `!analyze -v` again.

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
