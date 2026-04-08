# SenseKit Hook Config

Use this as the boring, known-good starting point for bring-up and debugging.

```json5
{
  hooks: {
    enabled: true,
    token: "${OPENCLAW_HOOKS_TOKEN}",
    path: "/hooks",
    maxBodyBytes: 65536,
    defaultSessionKey: "hook:sensekit",
    allowRequestSessionKey: false,
    allowedSessionKeyPrefixes: ["hook:"],
    allowedAgentIds: ["main"],
    mappings: [
      {
        match: { path: "sensekit" },
        action: "agent",
        agentId: "main",
        wakeMode: "now",
        name: "SenseKit",
        sessionKey: "hook:sensekit:{{batch_id}}",
        messageTemplate: "SenseKit batch: {{batch_id}}\nPlatform: {{device.platform}}\nPlace sharing: {{device.place_sharing_mode}}\nSignals: {{signals}}",
        deliver: false,
      },
    ],
  },
}
```

Notes:

- With `path: "/hooks"` and `match.path: "sensekit"`, the phone should post to `/hooks/sensekit`.
- Use the hooks token in the phone app as the bearer token.
- This direct mapping is for verifying delivery and inspecting the live batch.
- Keep the first version simple. No custom transform.
- Add a transform only when you need it, and only if it returns a full hook action object.
- In a production setup, prefer a trusted local action pipeline instead of turning raw webhook data directly into prompt instructions.

If you later add a transform, keep it narrow:

- validate the batch
- log the raw signal batch
- apply local rules, cooldowns, and dedupe
- emit a symbolic trusted action or a valid hook action object
- avoid building free-form prompt text from untrusted webhook fields

## Common mistakes

- Using stale field names like `event.id` or `event.type`
- Returning `null` or `{}` from a transform
- Testing a complex transform before the plain mapping works
- Letting raw webhook text decide what the agent should say
- Reusing `gateway.auth.token` instead of a separate hooks token
