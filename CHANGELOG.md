# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

## v0.2.0 - 2026-04-08

Raw-signal runtime update.

Included:

- shifted the runtime and contracts from legacy event envelopes to `sensekit.signal_batch.v1`
- removed the old corroboration, snapshot, and policy-envelope path from outbound delivery
- aligned the iOS app setup flow and product copy with the raw-signal model
- expanded the audit log so users can inspect the exact JSON sent to OpenClaw
- rewrote the SenseKit skill and example hook config around agent-safe raw signal handling
- refreshed the top-level docs, spec, privacy docs, and hosted policy materials

Known gaps:

- passive wake accuracy still requires real-device validation
- passive driving accuracy still requires real-commute validation
- battery and background-delivery reliability still need more field proof
- production OpenClaw deployments still need local trusted rule/dispatcher work on the receiver side

Documentation and repository polish in this release:

- rewrote the top-level README to present SenseKit more clearly as an open-source project
- added a docs index for easier navigation
- added security and support policies
- improved GitHub issue and pull request guidance for contributors

## v0.1.0 - 2026-03-09

First public scaffold release.

Included:

- monorepo layout for iOS, contracts, OpenClaw packages, and docs
- deterministic corroboration engine with initial event configs
- runtime collectors for Motion, Location, HealthKit, power, and calendar
- SQLite-backed runtime state, offline queue, and audit log
- signed OpenClaw webhook delivery
- SwiftUI app shell and separate bench harness target
- JSON schemas, fixtures, and TypeScript validation helpers
- ADRs, privacy docs, and initial field-test runbooks
- GitHub CI, issue templates, and contribution docs

Known gaps:

- passive wake accuracy still requires real-device validation
- passive driving accuracy still requires real-device validation
- battery and background-reliability claims are not yet proven in field tests
- Shortcuts boosts are scaffolded but not yet a finished user-facing flow
