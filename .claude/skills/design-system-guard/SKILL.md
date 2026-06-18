---
name: design-system-guard
description: "Activate when developing, modifying, or refactoring UI layouts, custom widgets, styling, assets setup, or anything within the style system package."
---

# Capability: Design System Guard

## 1. Architectural Separation
- All reusable UI elements, theme data, design tokens, colors, and font configurations belong strictly inside `packages\worklog_studio_style_system\lib\`.
- The main app `apps\worklog_studio` must consume UI components only by importing this package.

## 2. Hardcoding Prevention
- Reject any attempt to hardcode colors (`Color(0xFF...)`), arbitrary paddings, or text styles directly inside `apps\worklog_studio`.
- Always enforce using the design system's theme context (e.g., extensions, custom theme tokens).

## 3. Public API Mapping
- When creating or updating a custom widget inside `packages\worklog_studio_style_system\lib\src\`, verify that it is properly exported in the package's main barrel file so it becomes instantly accessible to the main application.
