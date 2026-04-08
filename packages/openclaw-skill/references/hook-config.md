# SenseKit Hook Config

Use this as the boring, known-good starting point.

```json5
{
  hooks: {
    enabled: true,
    token: "${OPENCLAW_HOOKS_TOKEN}",
    path: "/hooks",
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
        messageTemplate: "SenseKit batch: {{batch_id}}\nPlatform: {{device.platform}}\nSignals: {{signals}}",
        deliver: false,
      },
    ],
  },
}
```

Notes:

- With `path: "/hooks"` and `match.path: "sensekit"`, the phone should post to `/hooks/sensekit`.
- Use the hooks token in the phone app as the bearer token.
- Keep the first version simple. No custom transform.
- Add a transform only when you need it, and only if it returns a full hook action object.

## Common mistakes

- Using stale field names like `event.id` or `event.type`
- Returning `null` or `{}` from a transform
- Testing a complex transform before the plain mapping works
- Reusing `gateway.auth.token` instead of a separate hooks token
