# SenseKit Privacy Policy

Last updated: April 7, 2026

SenseKit is an iPhone app for passive context detection. It listens for a limited set of device signals, turns them into structured events, and sends those events to the OpenClaw endpoint configured by the user.

## What SenseKit collects

- Motion & Fitness activity that helps detect wake and driving state
- Location used to capture saved places, improve driving detection, and monitor arrivals and departures
- Runtime configuration the user enters, such as the OpenClaw endpoint URL, bearer token, HMAC secret, and saved place labels
- Local debug timeline and audit log entries that explain what the runtime saw and what it tried to deliver

## What SenseKit sends off device

When configured, SenseKit sends one structured event at a time to the user’s chosen OpenClaw endpoint. Those payloads can include:

- event type
- event time
- confidence
- short reasons
- coarse place labels such as `home`, `work`, or another saved place
- simple device state such as battery bucket and charging status

## What SenseKit does not send by default

- raw GPS traces or exact coordinates
- raw motion history
- calendar titles or attendee lists
- raw Health data
- local debug payloads
- bearer tokens or HMAC secrets

## On-device storage

SenseKit stores runtime configuration, timeline entries, and audit history on device so the user can review what happened locally.

## Permissions

SenseKit currently focuses on Motion & Fitness and location-based closed-beta testing.

- Motion & Fitness is used to detect wake and driving changes on-device.
- Location is used to capture places and detect arrivals, departures, and driving support.
- Calendar and HealthKit copy is included for upcoming integrations, but those flows are not the primary focus of this closed beta.

## Your choices

You can stop data collection by:

- turning features off in the app’s Setup flow
- revoking permissions in iPhone Settings
- deleting the app to remove local beta data

## Contact

For beta feedback or privacy questions, use the feedback email shown in TestFlight for the SenseKit beta.
