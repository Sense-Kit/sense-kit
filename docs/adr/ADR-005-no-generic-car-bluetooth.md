# ADR-005: Generic Car Bluetooth is Excluded from MVP

- Status: Accepted
- Date: 2026-03-09

## Decision

Driving detection uses Motion first and optional Location corroboration. Generic car Bluetooth is not part of MVP.

## Why

- Public iOS APIs do not safely expose normal car Bluetooth state
- CoreBluetooth does not solve Classic Bluetooth car audio
- Building around it would create a fake capability

