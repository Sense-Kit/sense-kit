# ADR-006: Driving Uses Motion Baseline and Location as Optional Boost

- Status: Accepted
- Date: 2026-03-09

## Decision

Driving works with Motion alone. Location improves timing and confidence but does not block first-run value.

## Why

- Requiring Location for Driving adds onboarding friction
- Motion-only is weaker but still usable with hysteresis and cooldowns

