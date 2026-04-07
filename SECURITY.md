# Security Policy

## Supported versions

SenseKit is still early-stage software. Security fixes are currently tracked against:

- the latest commit on `main`
- the latest tagged release

Older snapshots may receive fixes on a best-effort basis, but only the current development line should be treated as supported.

## Reporting a vulnerability

Please do not open public GitHub issues for security reports.

Send reports to `julian@sensekit.ai` with:

- a short description of the issue
- the affected component or file
- impact if you know it
- clear reproduction steps or a proof of concept if you have one

If the report is valid, the goal is to acknowledge it within 3 business days and keep you updated until a fix or mitigation is available.

## Scope and expectations

The most sensitive areas in this repository are:

- webhook signing and verification paths
- token handling and configuration surfaces
- anything that could accidentally widen what leaves the device
- local data storage and debug export behavior

Please report suspected privacy leaks the same way you would report a security bug.
