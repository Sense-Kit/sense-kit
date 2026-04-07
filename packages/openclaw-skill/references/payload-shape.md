# SenseKit Payload Shape

SenseKit sends a JSON envelope with four important top-level sections:

- `event`: what happened
- `snapshot`: the current phone context around that event
- `policy`: what output styles are preferred or blocked
- `delivery`: queue metadata about the webhook send

## Top-level envelope

```json
{
  "schema_version": "sensekit.event.v1",
  "device_id": "iphone_julian",
  "event": { "...": "..." },
  "snapshot": { "...": "..." },
  "policy": { "...": "..." },
  "delivery": { "...": "..." }
}
```

## Event

Important fields:

- `event.event_id`
- `event.event_type`
- `event.occurred_at`
- `event.confidence`
- `event.reasons`
- `event.mode_hint`
- `event.cooldown_sec`
- `event.dedupe_key`

Known `event.event_type` values in the app:

- `motion_activity_observed`
- `health_snapshot_updated`
- `wake_confirmed`
- `driving_started`
- `driving_stopped`
- `arrived_place`
- `left_place`
- `arrived_home`
- `left_home`
- `arrived_work`
- `left_work`
- `workout_started`
- `workout_ended`
- `focus_on`
- `focus_off`

Known `event.mode_hint` values:

- `text_brief`
- `voice_safe`
- `voice_note`
- `normal`

## Snapshot

Useful fields:

- `snapshot.routine.awake`
- `snapshot.routine.focus`
- `snapshot.routine.workout`
- `snapshot.place.type`
- `snapshot.place.freshness`
- `snapshot.calendar.in_meeting`
- `snapshot.calendar.next_meeting_in_min`
- `snapshot.device.battery_percent_bucket`
- `snapshot.device.charging`

`snapshot.place.type` is one of:

- `home`
- `work`
- `custom`
- `other`

## Policy

Useful fields:

- `policy.event_type`
- `policy.allowed_actions`
- `policy.blocked_actions`
- `policy.delivery_channel_preference`
- `policy.ttl_sec`

The policy is there to shape the reply style. Example: if long markdown is blocked, do not lead with a long markdown response.

## Delivery

Useful fields:

- `delivery.attempt`
- `delivery.queued_at`

These fields are mostly for debugging and retries, not for the user-facing message.
