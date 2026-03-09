## Summary

What changed?

## Why

Why was this change needed?

## Checks

- [ ] `pnpm build`
- [ ] `pnpm test`
- [ ] `pnpm contracts:check`
- [ ] `cd apps/ios/Packages/SenseKitRuntime && swift test`
- [ ] `cd apps/ios/Packages/SenseKitUI && swift test`
- [ ] `xcodebuild -workspace apps/ios/SenseKit.xcworkspace -scheme SenseKitApp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`

## Risks

Anything reviewers should watch closely?
