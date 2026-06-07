---
name: surgical-refactor-pro
description: "Activate when the user requests code reviews, deep widget tree optimization, memory leak fixes, or layout performance improvements."
---

# Capability: Surgical Refactoring & Performance

## 1. Context Minimization
- Before starting a refactoring task, explicitly identify the target file. Do not read surrounding files unless a direct dependency trace is required.
- Do not search or index any `.freezed.dart` or `.g.dart` code generation files.

## 2. Code Quality & Flutter Best Practices
- **Anti-Pattern Guard:** Actively combat deep widget tree nesting. Look for bloated `build` methods and force breaking them down into small, isolated `StatelessWidget` classes rather than large helper functions.
- Ensure that any controllers, streams, or change-notifiers created in stateful contexts are strictly closed or disposed of inside the lifecycle `dispose()` method.
- Maximize the use of the `const` constructor where applicable to prevent redundant widget rebuilds.
