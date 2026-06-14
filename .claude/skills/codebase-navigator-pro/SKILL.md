---
name: codebase-navigator-pro
description: "Activate when the user asks to explain feature logic, find code definitions, trace component dependencies, or navigate the worklog_studio codebase."
---

# Capability: Surgical Codebase Navigation

## 1. Context & Architecture Anchors
- You are working in a Melos monorepo rooted at the current workspace directory.
- The application entry points are `apps\worklog_studio\lib\main.dart` and `apps\worklog_studio\lib\main_development.dart`. Use them as references for the app's initialization and configuration lifecycle.
- UI Kit and shared styling live inside `packages\worklog_studio_style_system\lib\`.

## 2. Surgical Analysis Rules (Token Saving)
- **DO NOT** read entire directories or multiple files sequentially just to "browse" the project.
- **Grep-First Strategy:** Always use the `Grep` tool with exact class names, methods, or unique identifiers to locate logic before reading a file.
- **No Generated Files:** Under no circumstances should you read or search inside `*.freezed.dart` or `*.g.dart` files. Focus only on human-written Dart files.
- If a navigation or tracing task requires opening more than 3 files simultaneously, stop and outline your plan to the user first.
- Follow the tool priority in CLAUDE.md §6: native `Read`/`Grep`/`Glob` first, `filesystem` MCP as fallback.
