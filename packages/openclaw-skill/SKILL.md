---
name: sensekit-openclaw
description: Use this skill when connecting SenseKit webhooks to OpenClaw, debugging SenseKit hook mappings, or teaching an OpenClaw agent how to interpret SenseKit raw signal batches. It covers the known-good hook config, the real SenseKit payload shape, and how to respond safely to fields like signals[].signal_key, signals[].payload, and device.place_sharing_mode.
---

# SenseKit OpenClaw

SenseKit sends outbound raw signal batches from the phone to OpenClaw at `/hooks/sensekit`.

Use this skill for two jobs:

- configure the OpenClaw hook in a stable way
- interpret SenseKit signal batches inside the agent without guessing field names or output style

## Workflow

1. For hook setup or debugging, read `references/hook-config.md`.
2. For payload questions, read `references/payload-shape.md`.
3. Start from the simple mapping first. Do not add a `transform` unless it returns a full hook action object.
4. Prefer the bundled `templates/message-template.txt` or a close variant.

## Agent behavior

- Treat SenseKit as a system signal feed, not as a normal user chat message.
- Start from `signals`, especially `signals[].signal_key`, `signals[].collector`, and `signals[].payload`.
- Read the whole batch before reacting. Several weak signals together can matter more than any one signal alone.
- Prefer interpreting combinations like motion + location + power, not just one field in isolation.
- `device.place_sharing_mode` tells you whether missing coordinates are expected.
- If the batch is mixed or ambiguous, ask a short confirmation instead of acting certain.

## Hook mapping rules

- SenseKit payloads use snake_case field names.
- Known-good templates use `batch_id`.
- Use one stable session per batch, usually `hook:sensekit:{{batch_id}}`.
- Keep `deliver: false` while bringing the integration up unless there is a clear reason to push replies back automatically.
- A `transform` is optional. If used, it must return a valid hook action object. Returning `null` or `{}` can break the mapping.

## Debugging

- If OpenClaw returns `hook mapping failed`, remove custom transforms first and retry with the example mapping unchanged.
- If template values are blank, check for stale field names from the old payload shape such as `event.id`, `event.type`, or `snapshot.place.type`.
- If the agent reacts oddly, compare the live payload against `references/payload-shape.md`.
