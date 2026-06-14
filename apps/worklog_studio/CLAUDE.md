# Worklog Studio App — TDD Guidelines

## Test-Driven Development (TDD) — Mandatory
All new business logic and bug fixes **must** follow the Red → Green → Refactor cycle.

**Rules:**
- **Write the test first.** Before writing any implementation code for a new feature or fix, write a failing test that defines the expected behaviour. Commit or at minimum present the failing test before touching production code.
- **Minimal implementation.** Write only enough production code to make the failing test pass. Do not add untested logic speculatively.
- **Refactor under green.** Once the test is green, clean up the implementation. The test suite must remain green throughout refactoring.
- **No production code without a test.** Every new public method, service, use-case, or domain rule must have a corresponding unit test in `apps\worklog_studio\test\`. UI-only changes are exempt, but any logic extracted from a widget must be tested.
- **Test location conventions:**
  - Pure domain / service logic → `test\core\`
  - Bloc / state-machine behaviour → `test\feature\`
  - Shared fakes and helpers → `test\helpers\`
- **Test doubles:** Prefer hand-rolled fakes (see `test\helpers\test_fakes.dart`) for stateful collaborators. Use `mocktail` mocks only for pure event-sources or when the collaborator has no meaningful state.
- **Tests must pass before build.** `fvm flutter test test/core/ test/feature/` is executed by `build.sh`, `build.ps1`, and the CI `test` job. A red test blocks the build.
