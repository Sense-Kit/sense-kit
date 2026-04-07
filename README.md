# SenseKit

SenseKit is an open-source context runtime for AI agents.

It runs on iPhone, listens to passive sensor signals, turns them into deterministic context events, and delivers those events to OpenClaw over signed HTTPS.

The goal is simple: an AI agent should understand important real-world transitions without asking the user to build Shortcuts automations first.

## Product thesis

SenseKit is:

- passive-first
- event-first
- deterministic
- local-first
- OpenClaw-first

That means:

- the iPhone app should do useful work right after install and permissions
- event detection uses fixed weights and thresholds, not ML guesses
- raw sensor data stays local by default
- the main integration is an outbound webhook, not a phone-hosted server

This repository is a monorepo. It keeps the iOS runtime, shared wire contracts, OpenClaw integration helpers, and project docs together because they change together.

## What works today

This repo already includes the first serious product scaffolding:

- a deterministic corroboration engine for passive events
- a Swift runtime package with Motion, Location, HealthKit, power, and calendar collectors
- SQLite-backed runtime state, queue, and audit log
- signed webhook delivery for OpenClaw
- a SwiftUI app shell with onboarding, settings, audit log, and debug timeline scaffolding
- a separate bench harness target for field testing
- shared JSON schemas and TypeScript validation helpers

What is not proven yet:

- real-device wake precision
- real-device driving precision
- battery impact over normal daily use
- final onboarding polish

In other words: the architecture and build system are in place, but the passive claims still need bench validation.

## Repo layout

- `apps/ios`: iPhone app, bench harness, Swift runtime package, and SwiftUI package
- `packages/contracts`: JSON schemas, fixtures, and TypeScript validation helpers
- `packages/openclaw-skill`: example skill packaging for OpenClaw
- `packages/openclaw-plugin`: plugin surface for later OpenClaw integration work
- `packages/examples`: webhook and QR bootstrap examples
- `docs`: ADRs, privacy notes, bench plans, and runbooks

## Local setup

Requirements:

- Xcode with `iOS 17+` SDK support
- Node.js and `pnpm`
- Ruby only if you want to regenerate the Xcode project with `scripts/generate_ios_project.rb`

Install JavaScript dependencies:

```bash
pnpm install
```

Run the TypeScript workspace checks:

```bash
pnpm build
pnpm test
pnpm contracts:check
```

Run Swift package tests:

```bash
cd apps/ios/Packages/SenseKitRuntime && swift test
cd apps/ios/Packages/SenseKitUI && swift test
```

Build the iOS app targets:

```bash
xcodebuild -workspace apps/ios/SenseKit.xcworkspace -scheme SenseKitApp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace apps/ios/SenseKit.xcworkspace -scheme SenseKitBenchApp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## OpenClaw connectivity and security

For personal testing, keep OpenClaw private and use Tailscale instead of exposing the raw Gateway to the public internet.

- Recommended first setup: OpenClaw stays on `gateway.bind: "loopback"` and is exposed privately with Tailscale Serve.
- Do not expose the raw OpenClaw Gateway port publicly just to receive SenseKit hooks. The Gateway is a larger surface than one webhook path.
- Use a separate `hooks.token` for SenseKit hooks. Do not reuse `gateway.auth.token`.
- Treat hook payloads as untrusted content even when they come from systems you control. Keep the receiving agent narrow and low-privilege.
- A public hook-only reverse proxy or a small verifier relay can come later, but they are not the safest first deployment.

## First development focus

If you want to help on the MVP, the highest-value work is:

1. passive wake validation on real devices
2. driving detection validation on real commutes
3. background wake and delivery reliability
4. onboarding and debug timeline polish

The best starting docs are:

- `docs/adr`
- `docs/bench/phase-1a-field-test.md`
- `docs/runbooks/runtime-bootstrap.md`

## Open source notes

- License: Apache-2.0
- Contributions are welcome. See `CONTRIBUTING.md`
- Architecture decisions live in `docs/adr`
