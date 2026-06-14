---
name: codegen-sentinel
description: "Activate when working with data models, DTOs, state management classes, or files utilizing build_runner code generation."
---

# Capability: Code Generation Management

## 1. Strict File Exclusion
- **NEVER** open, read, or scan generated files ending with `.freezed.dart` or `.g.dart`. They consume excessive tokens.
- When the user asks to modify a model or state, locate and modify *only* the source file (e.g., `user_model.dart`). You must infer the generated structure conceptually without reading the output files.

## 2. Post-Modification Protocol
- After editing any file that uses `@freezed`, `@JsonSerializable`, or other code-generation annotations, you must explicitly remind the user to run the build runner.
- Provide the exact command wrapped for FVM. Target the specific package/app directory where the change occurred.
  * *Example command to suggest:* `fvm flutter pub run build_runner build --delete-conflicting-outputs`
