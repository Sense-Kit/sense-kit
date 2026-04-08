# SenseKit Privacy Policy

Last updated: April 8, 2026

SenseKit is an iPhone app that watches a limited set of device signals and can forward them to an OpenClaw endpoint chosen by the user. This policy covers the current SenseKit iOS beta and is written to match the app's actual architecture in this repository.

## Summary

- SenseKit does not use ad SDKs or cross-app tracking in the current beta.
- SenseKit creates an app-specific device ID on first run.
- The app stores configuration locally on the iPhone and keeps runtime data in a local SQLite database.
- If you configure OpenClaw, SenseKit sends signed HTTPS requests to that endpoint.
- Those requests can include motion, location, power, and workout metadata, depending on the features you enable and the permissions you grant.
- The configured bearer token is sent in the HTTP `Authorization` header to your chosen endpoint.
- The HMAC secret itself stays on device. SenseKit sends a derived signature header, not the raw secret.
- If you search for an address or place during setup, Apple services such as MapKit search and geocoding may receive that search query.

## Information SenseKit stores on your device

SenseKit currently stores the following information locally on the device:

- an app-generated device ID
- runtime settings such as enabled features, wake window, driving-location boost, and place sharing mode
- saved places you configure, including labels, coordinates, and radius
- OpenClaw connection settings, including endpoint URL, bearer token, and HMAC secret
- locally collected motion, location, power, and optional workout signals
- runtime state such as the current known place
- queued webhooks, audit log entries, and debug timeline entries

## Information SenseKit can send off your device

### 1. To your configured OpenClaw endpoint

If you configure an OpenClaw endpoint, SenseKit can send:

- an app-specific device ID, platform, and place sharing mode
- raw signal batches with timestamps, source names, queue attempt metadata, and signal payloads
- motion activity flags and confidence
- battery state and battery level changes
- place enter and exit events, place identifiers, place types, and place labels you saved
- significant location change data such as speed, course, altitude, and accuracy
- exact latitude and longitude only when you enable precise place sharing
- HealthKit workout metadata when the workout feature is enabled and permission is granted
- the bearer token in the HTTP `Authorization` header
- an HMAC signature in the `X-SenseKit-Signature` header and a timestamp in `X-SenseKit-Timestamp`

If you do not configure an OpenClaw endpoint, SenseKit does not send webhook traffic.

Because you choose the OpenClaw endpoint, data received there is handled under that endpoint operator's privacy and retention practices, not under this policy.

### 2. To Apple services used during setup

When you use the place search UI, SenseKit can use Apple services such as MapKit local search and geocoding to turn your query into a saved place. That means your search text and the place you select may be handled by Apple as part of that lookup.

## Information SenseKit does not currently send by default

SenseKit does not currently send the following by default:

- the raw HMAC secret itself
- calendar titles or attendee lists
- a full HealthKit export history
- continuous second-by-second foreground GPS tracking
- local debug timeline and audit history to SenseKit-operated servers

## How SenseKit uses permissions

- Motion & Fitness: to detect movement changes such as walking, running, cycling, automotive, and stationary states
- Location: to monitor saved places, observe significant location changes, and optionally include exact coordinates if you choose precise sharing
- HealthKit: to observe workout samples when you enable the workout feature

## Storage and retention

- The current beta stores configuration in local app storage on the device.
- The current beta stores runtime data in a local SQLite database inside the app container.
- Active signals are pruned as they expire.
- Local audit history, debug history, and queued delivery records can remain on the device until you delete the app. The current beta does not yet provide a separate in-app delete control for those records.
- Data sent to your configured OpenClaw endpoint is retained according to that endpoint operator's rules, not by SenseKit.

## Your choices and controls

You can reduce or stop data collection by:

- leaving OpenClaw unconfigured so collected signals stay on device
- choosing label-only place sharing instead of precise coordinates
- enabling or disabling features inside the app
- revoking Motion, Location, or HealthKit access in iPhone Settings
- avoiding address search if you do not want to use Apple place lookup services
- deleting the app to remove local app data managed by iOS

## No tracking or sale

SenseKit does not use third-party advertising SDKs, does not sell personal data, and does not perform cross-app tracking in the current beta.

## Contact

For privacy or security questions, email [julian@sensekit.ai](mailto:julian@sensekit.ai).
