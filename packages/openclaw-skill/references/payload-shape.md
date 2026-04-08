# SenseKit Payload Shape

SenseKit sends one raw signal batch as JSON.

What the agent receives:

- one top-level object with `schema_version: "sensekit.signal_batch.v1"`
- no top-level `event`, `snapshot`, or `policy`
- one or more raw observations in `signals[]`
- queue metadata in `delivery` for retry/debug work

## Top-level batch

```json
{
  "schema_version": "sensekit.signal_batch.v1",
  "batch_id": "batch_123",
  "sent_at": "2026-04-08T08:15:00Z",
  "device": { "...": "..." },
  "signals": [{ "...": "..." }],
  "delivery": { "...": "..." }
}
```

The important top-level sections are:

- `device`: phone-level context and privacy mode
- `signals`: the actual collector output the agent or local rules should inspect
- `delivery`: queue metadata about this send attempt

## Device

Useful fields:

- `device.device_id`
- `device.platform`
- `device.place_sharing_mode`

`device.place_sharing_mode` is one of:

- `labels_only`
- `precise_coordinates`

If coordinates are missing while the mode is `labels_only`, that is expected.

## Signals

Every item in `signals[]` is a raw collector observation.

Useful fields:

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

What those fields mean:

- `signal_key`: the main semantic label for the observation
- `collector`: which subsystem produced it
- `source`: the lower-level source inside that collector
- `weight`: how strongly this signal should count in local rule evaluation
- `polarity`: whether the signal supports or opposes a conclusion
- `observed_at`: when the phone observed the signal
- `received_at`: when the runtime recorded it; useful for delay debugging
- `valid_for_sec`: how long the signal should still be considered relevant
- `payload`: collector-specific details

Known `collector` values:

- `motion`
- `location`
- `power`
- `health`
- `manual`
- `unknown`

Common `signal_key` values in the app today:

- `motion.activity_observed`
- `location.region_state_changed`
- `location.location_observed`
- `power.battery_state_changed`
- `power.battery_level_observed`
- `health.workout_sample_observed`

Example payload fields:

- `motion.activity_observed`
  - `primary_kind`
  - `confidence`
  - `automotive`
  - `walking`
  - `running`
  - `stationary`
  - `cycling`
- `location.region_state_changed`
  - `transition`
  - `place_identifier`
  - `place_name`
  - `place_type`
  - `radius_m`
  - optional `latitude`
  - optional `longitude`
- `location.location_observed`
  - optional `latitude`
  - optional `longitude`
  - `horizontal_accuracy_m`
  - `vertical_accuracy_m`
  - `speed_mps`
  - `speed_kmh`
  - `course_deg`
  - `altitude_m`
  - `timestamp`
- `power.battery_state_changed`
  - `previous_state`
  - `current_state`
  - `battery_level`
  - `battery_level_percent`
  - `is_charging`
- `health.workout_sample_observed`
  - `uuid`
  - `activity_type`
  - `start_at`
  - `end_at`
  - `duration_sec`
  - optional `total_energy_kcal`
  - optional `total_distance_m`
  - optional `metadata_keys`

## How To Read A Batch

- Start with the set of `signal_key` values present in the batch.
- Then inspect `payload` for the collector-specific details.
- Use `weight`, `polarity`, and `valid_for_sec` to decide how much each signal should matter.
- Read several signals together before acting. The batch is raw evidence, not a final answer.
- If `device.place_sharing_mode` is `labels_only`, missing coordinates are normal.

## Generic Interpretation Ideas

- A wake-like signal does not have to trigger an immediate user-facing message. It can simply move the local system into a morning-ready state.
- Motion plus speed plus place transition signals can indicate a commute-like transition, even though SenseKit does not send a final `driving_started` event anymore.
- A workout sample can trigger recovery-oriented behavior without the phone deciding the final wording.
- Power signals can be used to defer, shorten, or reroute behavior when the moment looks bad for a long interruption.

## Delivery

Useful fields:

- `delivery.attempt`
- `delivery.queued_at`

These are mostly for debugging retries, not for user-facing messaging or rule meaning.
