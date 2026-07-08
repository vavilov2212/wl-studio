# work_log - Prototype Feature

This feature is **not active**. It is not wired into any `AppRoute` and is not reachable from the running app.

It was an earlier design iteration for a work-log import/automation flow (parsing raw session text via AI, matching to Jira issues, submitting time entries). It is kept here for reference.

**Do not:**
- Add this feature to the routing switch in `app_shell.dart`
- Write tests for it in its current state
- Refactor it as if it were production code

**To revive:** Start fresh with a proper spec and BLoC structure. The `WorkLogRawDataUsecase` and `WorkLogRawDataBloc` are registered in DI and can be reused as a starting point.
