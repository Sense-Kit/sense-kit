# SenseKit Closed Beta Release Notes

Last updated: April 7, 2026

This document is the operator checklist for shipping the first closed TestFlight beta of SenseKit.

## What changed in the beta build

- Added a real app icon asset catalog for the iOS target
- Added an explicit app `Info.plist` with clearer permission copy and background location declaration
- Added an app privacy manifest for `UserDefaults` access
- Added an in-app privacy policy entry point in Settings
- Added a written privacy policy and TestFlight checklist for App Store Connect

## Manual App Store Connect checklist

Before inviting external testers:

1. Create or update the App Store Connect app record for the exact bundle identifier used for this build.
2. Fill in the TestFlight test information:
   - beta app description
   - features to test
   - feedback email
3. Add a privacy policy URL that points to a hosted copy of `docs/privacy/privacy-policy.md`.
4. Complete App Privacy answers to match the actual beta behavior.
5. Complete export compliance questions for the app’s use of HTTPS and HMAC signing.
6. Upload a signed archive with a provisioning profile that contains the application identifier.
7. Add the first build to an external tester group and wait for Beta App Review.

## Suggested “What to Test” text

Focus on three things:

- motion-based wake and driving detection
- place setup, home/work region monitoring, and background arrivals or departures
- webhook delivery, audit log entries, and failure handling when the endpoint is wrong or unreachable

## Suggested App Review notes

SenseKit is a closed beta for passive signal delivery to a user-configured OpenClaw endpoint. The main beta flows are Motion & Fitness observations, background location arrivals and departures, power state changes, and workout sample delivery. The app sends signed raw signal batches instead of pre-decided events. Calendar titles, attendee lists, bearer tokens, and HMAC secrets are not sent. Exact coordinates are only sent when the user explicitly enables precise place sharing.
