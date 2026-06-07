# /codegen

Run build_runner for a specific package after editing a model or state class.

**Usage:** `/codegen app` or `/codegen style`

- `app`   → runs inside `apps/worklog_studio/`
- `style` → runs inside `packages/worklog_studio_style_system/`

```bash
# For app:
cd apps/worklog_studio && fvm flutter pub run build_runner build --delete-conflicting-outputs

# For style system:
cd packages/worklog_studio_style_system && fvm flutter pub run build_runner build --delete-conflicting-outputs
```

Confirm which `*.freezed.dart` or `*.g.dart` files were regenerated.
