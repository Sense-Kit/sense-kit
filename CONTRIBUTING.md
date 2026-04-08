# Contributing to SenseKit

Thanks for contributing.

## What this project is trying to be

SenseKit is a passive-first, raw-signal context runtime for AI agents.

That means:
- collector behavior and outbound payloads should stay simple and explainable
- passive detection matters more than clever-looking code
- background behavior claims need real-device proof
- agents and LLMs may interpret signals after delivery, but SenseKit should not hide meaning behind opaque on-device logic

## Before you open a PR

Please keep changes small and focused.

Good PRs in this repo usually do one of these:
- improve one runtime module
- add or tighten tests
- improve docs, ADRs, or runbooks
- fix one concrete bug in the iOS or TypeScript side

Avoid giant mixed PRs that change runtime logic, schemas, UI, and docs all at once unless they truly must ship together.

## Local checks

Run the checks that match the part of the repo you changed.

JavaScript / TypeScript:

```bash
pnpm install
pnpm build
pnpm test
pnpm contracts:check
```

Swift packages:

```bash
cd apps/ios/Packages/SenseKitRuntime && swift test
cd apps/ios/Packages/SenseKitUI && swift test
```

iOS app build:

```bash
xcodebuild -workspace apps/ios/SenseKit.xcworkspace -scheme SenseKitApp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Architecture rules

Please preserve these rules unless you are explicitly proposing an ADR to change them:

- passive-first, not Shortcuts-first
- raw-signal-first delivery, not heavyweight on-device event synthesis
- outbound-only delivery, not phone-as-server
- minimal data leaving device by default
- no fake support for generic car Bluetooth on iPhone

## ADRs

If your change affects architecture, add or update an ADR in `docs/adr`.

Examples:
- changing the signal batch shape or signing rules
- adding a new background mechanism
- introducing a new package boundary

## Bench claims

If you claim a background behavior works reliably, say whether it is:
- `VERIFIED_BY_PLATFORM_DOCS`
- `REQUIRES_BENCH_TEST`
- `UNSAFE_TO_BUILD_AROUND`

This project is intentionally strict about that.
