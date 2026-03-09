# ADR-002: Weighted Corroboration vs Single-Signal Triggers

- Status: Accepted
- Date: 2026-03-09

## Decision

Events are emitted only when combined deterministic signal weight crosses an event threshold.

## Why

- Single signals are too noisy
- The engine must remain testable and explainable
- Fixed weights are easier to bench and debug than opaque heuristics

