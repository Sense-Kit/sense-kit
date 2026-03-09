# Runtime Bootstrap Runbook

On every launch:

1. Load `RuntimeConfiguration`
2. Load `RuntimeState` from SQLite
3. Re-register enabled collectors
4. Restore region states with `requestState(for:)`
5. Drain any due queue items
6. Record bootstrap entry in debug timeline

Time budget target:

- event callback to queue: under 10 seconds
- first delivery attempt: start within 5 seconds

