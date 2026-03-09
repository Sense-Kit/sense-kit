# SenseKit

SenseKit is an open-source context runtime for AI agents.

It runs on iPhone, listens to passive sensor signals, turns them into deterministic context events, and delivers those events to OpenClaw over signed HTTPS.

This repository is a monorepo. It keeps the iOS runtime, shared wire contracts, OpenClaw integration helpers, and project docs together because they change together.

## Repo layout

- `apps/ios`: iPhone app, bench harness, Swift runtime package, and SwiftUI package
- `packages/contracts`: JSON schemas, fixtures, and TypeScript validation helpers
- `packages/openclaw-skill`: example skill packaging for OpenClaw
- `packages/openclaw-plugin`: plugin surface for later OpenClaw integration work
- `packages/examples`: webhook and QR bootstrap examples
- `docs`: ADRs, privacy notes, bench plans, and runbooks

## Current status

The passive-first MVP scaffold is in place:

- deterministic corroboration engine
- SQLite-backed runtime state, queue, and audit log
- signed OpenClaw webhook delivery
- SwiftUI onboarding, settings, and debug timeline scaffolding
- shared JSON schemas and fixtures
- buildable iOS app and bench harness targets

This is not feature-complete yet. The next serious work is real-device validation for wake, driving, and background behavior.

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

## Open source notes

- License: Apache-2.0
- Contributions are welcome. See `CONTRIBUTING.md`
- Architecture decisions live in `docs/adr`
