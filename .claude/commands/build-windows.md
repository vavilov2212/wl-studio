# /build-windows

Bump version, run tests, and build the Windows release.

**Steps:**
1. Run the full test suite first — abort if any test fails.
2. Ask the user which version bump type to apply: `dev`, `release`, `patch`, `minor`, `major`, or an explicit `X.Y.Z`.
3. Run the Windows build script from the app directory:

```powershell
cd apps/worklog_studio
fvm flutter test test/core/ test/feature/ --reporter expanded
pwsh tool/windows/build.ps1 <type>
```

Report the new version number and the path of the generated ZIP.
