# ADR-003: Outbound-Only Delivery vs Phone-as-Server

- Status: Accepted
- Date: 2026-03-09

## Decision

The phone only sends signed outbound webhooks. It never exposes an inbound listener as the product core.

## Why

- iOS background listeners are not reliable enough to build around
- OpenClaw already has a hook model
- Outbound HTTPS is simpler to secure and explain

