# Changelog

All notable changes to this project will be documented in this file.

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
