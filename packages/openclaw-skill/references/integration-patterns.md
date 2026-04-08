# SenseKit Integration Patterns

Use this file when the question is not just "what fields are in the batch?" but "how should a real agent system use those fields safely?"

## Two Valid Modes

### 1. Direct batch inspection

Use this while bringing the integration up:

- map `/hooks/sensekit` directly to an agent
- keep `deliver: false`
- inspect the live batch and verify field names
- remove complexity until the plain mapping works

This mode is good for debugging, not for a mature production flow.

### 2. Trusted local action pipeline

Use this for production:

1. SenseKit sends a raw batch to `/hooks/sensekit`.
2. Local trusted code validates the payload and logs it.
3. Local rules inspect `signals[]`, apply cooldown and dedupe, and decide whether anything meaningful matched.
4. If something matched, local trusted code emits a small symbolic action.
5. A trusted local dispatcher maps that symbolic action to a local prompt template, routing target, and agent policy.
6. The dispatcher launches a short-lived agent run and records the outcome.

This keeps raw webhook data separate from trusted agent instructions.

## Trust Boundary

Treat these as untrusted:

- webhook payloads
- external metadata
- raw signal fields inside `payload`

Treat these as trusted local assets:

- rule evaluation code
- action whitelists
- prompt templates
- routing targets
- agent invocation policy
- cleanup logic

The webhook can trigger behavior, but it should not define behavior.

## Symbolic Actions

A symbolic action is a small trusted label produced by local rules after they inspect the batch.

Examples:

- `morning_handoff_ready`
- `commute_mode_candidate`
- `workout_recovery_ready`
- `low_battery_brief_only`

The action record should stay structured and boring. Useful fields include:

- `action_type`
- `batch_id`
- `device_id`
- `signal_keys`
- `target_channel`
- `target_recipient`
- `policy_tags`
- `created_at`

Avoid storing arbitrary webhook text as trusted action data.

## What Local Rules Should Do

Rules should:

- validate that the payload matches the expected batch shape
- inspect several signals together instead of guessing from one field
- use `weight`, `polarity`, `observed_at`, and `valid_for_sec`
- apply cooldowns and dedupe before emitting an action
- write enough debug data to explain why a match did or did not happen

Rules should not:

- write final user-facing prompt text from untrusted webhook data
- treat missing coordinates as an error when `place_sharing_mode` is `labels_only`
- assume every matched signal needs an immediate user-facing message

## Agent Run Model

Prefer agent runs that are:

- isolated
- one-shot
- short-lived

After the run:

- deliver the result through the chosen channel
- record the outcome
- clean up temporary session state

This avoids long-lived event-session sprawl.

## Observability

Keep separate logs for:

- raw inbound signal batches
- trusted queued actions
- dispatch and delivery outcomes

That separation makes it much easier to debug where a problem actually lives.
