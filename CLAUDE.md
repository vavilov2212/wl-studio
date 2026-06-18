# Core Directives

## 1. Structural & Output Constraints
- **No Verbose Reasoning**: Do not output verbose internal monologues, deep analytical paths, or extensive chain-of-thought blocks. Keep the focus entirely on execution.
- **Minimalist Action Logs**: If you need to report intermediate steps (e.g., searching, reading, or editing files), state the action in exactly one ultra-short phrase or sentence per action (e.g., "Searching for files...", "Updating configuration..."). Do not explain *why* you are doing it or what you expect to happen.
- **Direct Final Answer**: Provide a single, high-density, accurate final response at the very end. 
- **Formatting**: The final answer must be structured either as a concise bulleted list or a single focused paragraph. Eliminate all fluff, filler text, meta-commentary, and redundant explanations. Get straight to the point.

## 2. Tool Usage Priority
For any file exploration, reading, creating, editing, moving, or listing:
1. **First**, use native tools (`Read`, `Edit`, `Write`, `Glob`, `Grep`).
2. **If native tools are insufficient**, fall back to the `filesystem` MCP server tools.
3.  For symbol lookups (go-to-definition, find-references, document outline), **prefer the LSP tool over Grep/text search**. Only fall back to Grep if LSP returns no server/error.
4. **Only if both are insufficient**, use shell commands (Bash).

Shell commands remain the normal choice for everything that isn't a filesystem operation
(`fvm`/`melos`/`flutter`/`git` commands, builds, tests, etc.) — this priority order applies
specifically to file exploration/read/write/move/list operations.

# Worklog Studio Monorepo Configuration & Guidelines

## 1. Project Architecture & Path Map
This is a Flutter monorepository managed via Melos.
- **Root Directory:** Workspace root containing `melos.yaml`.
- **Main Application:** `apps\worklog_studio\`
  * *Entry Points:* `apps\worklog_studio\lib\main.dart` and `apps\worklog_studio\lib\main_development.dart`.
- **UI Kit & Design System:** `packages\worklog_studio_style_system\`
  * *Entry Point:* `packages\worklog_studio_style_system\lib\worklog_studio_style_system.dart` (barrel export file).

## 2. Environment Constraints (Strictly Windows)
- The development environment is **Windows**. All filesystem paths must use backslashes (`\`).
- Completely ignore and never crawl platform-specific directories for other OS targets (`macos\`, `ios\`, `android\`, `linux\`, `web\`).

## 3. Strict Token Optimization & File Exclusions
To optimize context limits and minimize token waste, your file-reading, search, or listing tools (native `Read`/`Grep`/`Glob`, or the `filesystem` MCP server as fallback) **MUST NEVER** access, search, or index:
- `.fvm\` (Internal SDK cache)
- `.git\` (Version control metadata)
- `.dart_tool\` (Local transient dart files)
- `**\build\` (All build and compilation artifacts)
- `*.freezed.dart` and `*.g.dart` (All auto-generated code-gen files)

## 4. Tooling & Command Cheatsheet
Always use `fvm` as a wrapper for commands. Never run global `flutter` or `dart`.
- **Bootstrap Monorepo:** `fvm exec melos bootstrap` (Run from root)
- **Clean Project:** `fvm exec melos clean`
- **Get/Resolve Dependencies:** `fvm exec melos bootstrap` from root — never run bare `flutter pub get` / `dart pub get` in a subdirectory (see `melos-dependency-manager` skill)
- **Run Code Generation:** `fvm flutter pub run build_runner build --delete-conflicting-outputs` (Inside specific package/app directory)
- **Run Tests:** `fvm flutter test test/core/ test/feature/ --reporter expanded` (From `apps\worklog_studio\`) — see `apps\worklog_studio\CLAUDE.md` for the mandatory TDD workflow.

## 5. Active Project Skills Matrix
You have 7 custom Project Skills configured. Analyze the user's prompt and internally align your behavior with the corresponding skill:
1. `codebase-navigator-pro`: Use for code exploration, logic tracing, and onboarding. Enforces "Grep-First" strategy.
2. `codegen-sentinel`: Use when editing models or classes with annotations. Enforces the `.freezed.dart` exclusion and reminds about build_runner.
3. `l10n-asset-stubber`: Use for UI tasks. Enforces an asset freeze (use `Placeholder()`, standard `Icons`) and requires hardcoded strings to have `// TODO: l10n`.
4. `melos-dependency-manager`: Use when modifying `pubspec.yaml` files, syncing versions, or using Melos.
5. `design-system-guard`: Use to protect the separation between app logic and the UI kit. Prevents hardcoded colors/paddings in `apps\`.
6. `surgical-refactor-pro`: Use for deep code reviews, optimizing widget trees, splitting widgets, and cleaning memory leaks (`dispose`).
7. `windows-desktop-expert`: Use for desktop lifecycle, shortcuts, window sizing, and native Windows integration.