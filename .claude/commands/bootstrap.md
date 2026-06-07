# /bootstrap

Re-link all monorepo packages and fetch dependencies.

Run from the workspace root — this is the only correct way to get dependencies in this Melos monorepo. Never run bare `flutter pub get` inside subdirectories.

```bash
fvm exec melos bootstrap
```

Confirm that all packages resolved without version conflicts. If conflicts are found, activate the `melos-dependency-manager` skill and propose a resolution.
