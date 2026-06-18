# /test

Run the full unit test suite and report results.

```bash
cd apps/worklog_studio && fvm flutter test test/core/ test/feature/ --reporter expanded
```

After running, summarize:
- Total tests passed / failed
- Any failing test names and the assertion that failed
- Whether it is safe to proceed with a build
