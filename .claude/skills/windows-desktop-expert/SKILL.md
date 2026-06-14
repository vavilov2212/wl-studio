---
name: windows-desktop-expert
description: "Activate when handling desktop-specific logic, window behaviors, keyboard listeners, system tray integrations, or Windows OS compatibility."
---

# Capability: Windows Desktop Architecture

## 1. Environment Constraints
- The user is developing exclusively for the **Windows Desktop** platform.
- Completely ignore all mobile-centric features, touch-only gestures, or platform APIs built for Android/iOS.
- Avoid looking into non-Windows directories (`macos\`, `ios\`, `android\`).

## 2. Desktop Behavior Patterns
- Focus on native desktop UX paradigms: window sizing constraints, window positioning, system tray minimization, mouse hover interactions, and proper keyboard focus traversal.
- Ensure shortcut triggers use explicit desktop bindings (Control, Alt, Shift combinations) native to the Windows ecosystem.
- If desktop lifecycle packages (like `window_manager`) are used, make sure their initialization calls align cleanly with the entry lifecycle in `main.dart`.
