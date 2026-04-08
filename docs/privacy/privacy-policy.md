# SenseKit Privacy Policy

Last updated: April 8, 2026

SenseKit is an iPhone app for passive context detection. It listens for device signals and sends raw signal batches to the OpenClaw endpoint configured by the user.

## What SenseKit collects

- Motion & Fitness activity observations from Core Motion
- Location signals used to capture saved places, monitor arrivals and departures, and observe background location changes
- Power state changes such as charging and battery level updates
- Workout sample updates from HealthKit when the related feature is enabled
- Runtime configuration the user enters, such as the OpenClaw endpoint URL, bearer token, HMAC secret, and saved place labels
- Local debug timeline and audit log entries that explain what the runtime saw and what it tried to deliver

## What SenseKit sends off device

When configured, SenseKit sends raw signal batches to the user’s chosen OpenClaw endpoint. Those payloads can include:

- motion activity flags and confidence
- location region transition data
- speed, course, altitude, and accuracy from location observations
- exact coordinates when precise place sharing is enabled
- charging state and battery level changes
- workout sample metadata such as activity type, start/end time, duration, and totals
- signal timestamps and collector/source metadata

## What SenseKit does not send by default

- calendar titles or attendee lists
- bearer tokens or HMAC secrets
- local debug payloads

## What depends on settings

- Exact coordinates are included only when precise place sharing is enabled.
- HealthKit workout signals are sent only when the workout feature is enabled and Health access is granted.
- If OpenClaw is not configured, SenseKit still records local audit/debug entries but does not send webhook traffic.

## What SenseKit does not currently send

- calendar titles or attendee lists
- continuous raw GPS traces
- full HealthKit export history

## On-device storage

SenseKit stores runtime configuration, timeline entries, and audit history on device so the user can review what happened locally.

## Permissions

SenseKit currently focuses on Motion & Fitness, Location, and workout-related HealthKit testing.

- Motion & Fitness is used for passive motion observations.
- Location is used to capture places and detect background region and movement changes.
- HealthKit is used for workout sample observation when enabled by the user.

## Your choices

You can stop data collection by:

- turning features off in the app’s Setup flow
- removing the OpenClaw endpoint configuration in the app
- revoking permissions in iPhone Settings
- deleting the app to remove local beta data

## Contact

For beta feedback or privacy questions, use the feedback email shown in TestFlight for the SenseKit beta.
