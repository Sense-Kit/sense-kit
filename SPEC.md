# SenseKit Spec

**Status:** Active
**Date:** April 8, 2026
**Owner:** codecoast labs
**Positioning:** OpenClaw-first, local-first, passive-first, raw-signal-first

## Thesis

SenseKit is an iPhone runtime that observes real device signals and forwards them to OpenClaw in signed JSON batches.

The phone does not decide the final meaning first.
OpenClaw gets the rawer possibilities and decides what they mean.

## Current Architecture

SenseKit now works like this:

1. iPhone collectors observe system signals.
2. SenseKit stores those signals locally and writes debug/audit entries.
3. SenseKit batches the signals into `sensekit.signal_batch.v1`.
4. SenseKit signs the payload and sends it to the configured OpenClaw hook.
5. OpenClaw decides whether the signals mean wake, driving, arrival, workout completion, or something else.

## Primary Payload

SenseKit sends `sensekit.signal_batch.v1`.

Top-level fields:

- `schema_version`
- `batch_id`
- `sent_at`
- `device`
- `signals`
- `delivery`

Each signal contains:

- `schema_version`
- `signal_id`
- `signal_key`
- `collector`
- `source`
- `weight`
- `polarity`
- `observed_at`
- `received_at`
- `valid_for_sec`
- `payload`

## Collectors

SenseKit currently supports these raw collectors:

- Motion via Core Motion
- Location via Core Location
- Power via `UIDevice`
- Workout samples via HealthKit
- Manual test scenarios for bench testing

Examples of signal keys:

- `motion.activity_observed`
- `location.region_state_changed`
- `location.location_observed`
- `power.battery_state_changed`
- `power.battery_level_observed`
- `health.workout_sample_observed`

## Background Behavior

SenseKit is designed to keep emitting signals when the app is backgrounded or the phone is locked, as far as iOS allows:

- Motion uses background-capable activity updates.
- Region monitoring and location updates can relaunch or wake the app.
- Power state changes are observed from the passive runtime.
- HealthKit workout observer delivery can wake the app for workout changes.

iOS still controls exact timing. SenseKit does not promise zero-delay delivery for every source.

## Privacy Boundary

SenseKit is local-first:

- it stores runtime state, timeline, and audit history on-device
- it only sends to the OpenClaw endpoint the user configures
- it signs outbound requests with HMAC

SenseKit does not currently send calendar titles, attendee lists, or the raw HMAC secret itself.
SenseKit does send the configured bearer token in the HTTP `Authorization` header and a derived HMAC signature header to the user-configured endpoint.

Exact coordinates are only sent when `place_sharing_mode` is `precise_coordinates`.

## Explicit Non-Goals

SenseKit does not currently try to:

- normalize signals into final events before delivery
- build a heavyweight snapshot object before delivery
- run a local policy engine before delivery
- act as a general behavioral-data warehouse

## Test Path

The app includes manual test scenarios for bench work.

These scenarios do not fake final events.
They emit representative raw signal groups through the same queue and delivery path used by live collectors.
