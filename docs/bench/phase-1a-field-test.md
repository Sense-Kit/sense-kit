# Phase 1A Field Test

This is the minimum real-device gate before wider build-out.

## Engineer A

1. Run Wake on your primary phone for 3 mornings.
2. Label every emitted wake as `correct`, `late`, or `false`.
3. Run one overnight battery session with Wake + Driving enabled.
4. Run two commute sessions:
   - one real car route
   - one transit control route

## Engineer B

1. Install the bench harness on a second phone.
2. Run one wake sanity check.
3. Verify webhook delivery, queue behavior, and audit visibility.
4. Validate hook payloads against the JSON fixtures.

## Hard gate

- Wake false positives must stay under 10%
- Driving cannot flap during one normal commute
- Queue must not lose events offline

