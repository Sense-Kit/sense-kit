## Summary

What changed?

## Why

Why was this change needed?

## Scope

- [ ] Runtime logic
- [ ] iOS UI
- [ ] Contracts / schemas
- [ ] Docs only
- [ ] Tooling / CI

## Validation

- [ ] `pnpm build`
- [ ] `pnpm test`
- [ ] `pnpm contracts:check`
- [ ] `cd apps/ios/Packages/SenseKitRuntime && swift test`
- [ ] `cd apps/ios/Packages/SenseKitUI && swift test`
- [ ] `xcodebuild -workspace apps/ios/SenseKit.xcworkspace -scheme SenseKitApp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`

## Docs and architecture

- [ ] README or docs updated if behavior changed
- [ ] ADR added or updated if architecture changed
- [ ] Background behavior claims are labeled as `VERIFIED_BY_PLATFORM_DOCS`, `REQUIRES_BENCH_TEST`, or `UNSAFE_TO_BUILD_AROUND`

## Risks

Anything reviewers should watch closely?
