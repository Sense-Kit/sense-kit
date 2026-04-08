# SenseKit Payload Shape

SenseKit now sends a raw signal batch as JSON.

The important top-level sections are:

- `device`: what kind of phone context rules were active
- `signals`: the actual observed collector output
- `delivery`: queue metadata about this send attempt

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
- `observed_at`
- `received_at`
- `payload`

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

## Delivery

Useful fields:

- `delivery.attempt`
- `delivery.queued_at`

These are mostly for debugging retries, not for user-facing messaging.
