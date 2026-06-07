# /tdd

Start a TDD cycle for a new feature or bug fix.

Follow the mandatory Red → Green → Refactor workflow defined in CLAUDE.md §5.

**Steps Claude must follow:**

1. **Understand** — ask the user to describe the behaviour to implement in one sentence.
2. **Red** — write the failing test(s) first in the correct location:
   - Domain / service logic → `apps/worklog_studio/test/core/`
   - Bloc / state-machine → `apps/worklog_studio/test/feature/`
   - Shared helpers → `apps/worklog_studio/test/helpers/`
3. **Confirm red** — run `fvm flutter test test/core/ test/feature/` and verify the new test(s) fail for the right reason.
4. **Green** — write the minimal production code to make the test(s) pass. No speculative logic.
5. **Confirm green** — run the test suite again; all tests must pass.
6. **Refactor** — clean up implementation and tests. Re-run tests to confirm still green.
7. **Report** — summarise what was added, what the tests cover, and confirm the suite is green.
