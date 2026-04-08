# SenseKit Agent Skill

This package contains the hook-facing and agent-facing assets for SenseKit.

Current contents:

- `SKILL.md`: agent guidance for raw signal batches and trusted local action flows
- `references/hook-config.md`: known-good webhook mapping
- `references/payload-shape.md`: real payload fields and signal batch shape
- `references/integration-patterns.md`: safer production patterns for turning raw signals into trusted agent work
- `templates/message-template.txt`: simple message template for hook delivery

The phone remains webhook-first in MVP. The plugin package is still optional later.
