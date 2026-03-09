# Bench Harness Target Notes

The bench harness app links the same runtime and UI packages as the main app, but it is meant for field testing and manual labeling.

Focus areas:

- extra debug logging enabled
- manual event labeling controls
- field-test export shortcuts

The entry source already exists at `BenchHarness/SenseKitBenchApp/SenseKitBenchApp.swift`.

To build it:

```bash
xcodebuild -workspace apps/ios/SenseKit.xcworkspace -scheme SenseKitBenchApp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```
