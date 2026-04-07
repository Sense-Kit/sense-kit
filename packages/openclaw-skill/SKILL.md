---
name: sensekit-openclaw
description: Use this skill when connecting SenseKit webhooks to OpenClaw, debugging SenseKit hook mappings, or teaching an OpenClaw agent how to interpret SenseKit events. It covers the known-good hook config, the real SenseKit payload shape, and how to respond safely to fields like event.event_type, event.confidence, event.mode_hint, snapshot.place.type, and policy.allowed_actions.
---

# SenseKit OpenClaw

SenseKit sends outbound context events from the phone to OpenClaw at `/hooks/sensekit`.

Use this skill for two jobs:

- configure the OpenClaw hook in a stable way
- interpret SenseKit events inside the agent without guessing field names or output style

## Workflow

1. For hook setup or debugging, read `references/hook-config.md`.
2. For payload questions, read `references/payload-shape.md`.
3. Start from the simple mapping first. Do not add a `transform` unless it returns a full hook action object.
4. Prefer the bundled `templates/message-template.txt` or a close variant.

## Agent behavior

- Treat SenseKit as a high-signal system event, not as a normal user chat message.
- Start from `event.event_type`, `event.confidence`, `event.mode_hint`, `snapshot.place.type`, and `policy`.
- `confidence` is how sure SenseKit is. Lower confidence means more caution.
- `mode_hint` is the default delivery style:
  - `voice_safe`: use 1-2 short sentences, avoid markdown-heavy formatting, avoid long option lists
  - `text_brief`: keep it short and direct
  - `voice_note`: prefer speech-friendly wording
  - `normal`: brief by default unless policy suggests otherwise
- `policy.allowed_actions`, `policy.blocked_actions`, and `policy.delivery_channel_preference` are guardrails. Do not lead with a blocked style.
- Treat `snapshot` as context, not certainty. It helps with timing and tone, but it is not a promise that the user wants an action.
- If `snapshot.routine.focus` is set, or the policy is restrictive, defer non-urgent content.
- If confidence is low or the state looks mixed, ask a short confirmation instead of acting certain.

## Hook mapping rules

- SenseKit payloads use snake_case field names.
- Known-good templates use `event.event_id` and `event.event_type`.
- Use one stable session per event, usually `hook:sensekit:{{event.event_id}}`.
- Keep `deliver: false` while bringing the integration up unless there is a clear reason to push replies back automatically.
- A `transform` is optional. If used, it must return a valid hook action object. Returning `null` or `{}` can break the mapping.

## Debugging

- If OpenClaw returns `hook mapping failed`, remove custom transforms first and retry with the example mapping unchanged.
- If template values are blank, check for stale field names like `event.id` or `event.type`.
- If the agent reacts oddly, compare the live payload against `references/payload-shape.md`.
