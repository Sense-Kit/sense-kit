# SenseKit Documentation

This folder holds the working documentation for SenseKit.

If you are new to the project, use this reading order:

1. [README.md](../README.md) for the high-level product and repo overview
2. [SPEC.md](../SPEC.md) for the product spec and event model
3. [docs/runbooks/runtime-bootstrap.md](runbooks/runtime-bootstrap.md) for the current integration and runtime bootstrap path
4. [docs/bench/phase-1a-field-test.md](bench/phase-1a-field-test.md) for real-device validation work
5. [docs/adr](adr) for the architecture rules that shape implementation decisions

## By topic

- [Architecture Decision Records](adr)
  - why the project is passive-first
  - why event detection is deterministic
  - why delivery is outbound-only
  - what platform constraints the project treats as real
- [Bench and validation docs](bench)
  - field-test plans
  - evidence for background behavior claims
- [Runbooks](runbooks)
  - runtime bootstrap and integration setup
- [Privacy docs](privacy)
  - minimization rules
  - privacy policy
- [Release notes](releases)
  - release snapshots and beta notes

## Recommended paths

Use these if you already know why you are here:

- Evaluating the project: [SPEC.md](../SPEC.md), [docs/adr](adr), [docs/bench/phase-1a-field-test.md](bench/phase-1a-field-test.md)
- Integrating with OpenClaw: [docs/runbooks/runtime-bootstrap.md](runbooks/runtime-bootstrap.md)
- Reviewing privacy and data handling: [docs/privacy/minimization.md](privacy/minimization.md), [docs/privacy/privacy-policy.md](privacy/privacy-policy.md)
- Contributing code or docs: [CONTRIBUTING.md](../CONTRIBUTING.md), [CHANGELOG.md](../CHANGELOG.md)
