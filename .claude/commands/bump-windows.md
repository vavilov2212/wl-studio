# /bump-windows

Bump version and run tests. Does not build — Windows packaging now happens only in CI, triggered by `publish.ps1`.

**Steps:**
1. Ask the user which version bump type to apply: `dev`, `release`, `patch`, `minor`, `major`, or an explicit `X.Y.Z`.
2. Run the bump script from the app directory (it updates `pubspec.yaml` and runs the test suite itself — abort if it fails):

```powershell
cd apps/worklog_studio
pwsh tool/windows/bump.ps1 <type>
```

Report the new version number and remind the user to run `publish.ps1` to push and trigger the CI build + release.
