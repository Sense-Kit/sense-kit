# Data Minimization Defaults

Local only by default:

- the raw HMAC secret itself
- local debug timeline and audit history
- calendar titles and attendees

Sent to the configured OpenClaw endpoint when available:

- the app-specific device ID and raw signal batches
- raw motion activity observations
- raw region transition payloads, including saved place labels when present
- significant location change fields such as speed, course, altitude, and accuracy
- battery state and battery level changes
- workout sample metadata when the feature is enabled
- the bearer token in the HTTP `Authorization` header
- a derived HMAC signature header
- exact coordinates only when precise place sharing is enabled

Handled by Apple during setup when the user invokes place lookup:

- address and place search queries entered into the setup UI
