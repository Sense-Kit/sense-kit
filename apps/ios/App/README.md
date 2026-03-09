# iOS App Target Notes

This repo now includes a generated Xcode project and a buildable app target.

Current pieces:

- runtime package: `Packages/SenseKitRuntime`
- UI package: `Packages/SenseKitUI`
- app entry source: `App/SenseKitApp/SenseKitApp.swift`
- generated project: `SenseKitApp.xcodeproj`
- workspace: `SenseKit.xcworkspace`

To rebuild the app target from the command line:

```bash
xcodebuild -workspace apps/ios/SenseKit.xcworkspace -scheme SenseKitApp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

If the Xcode project needs to be regenerated, use:

```bash
ruby scripts/generate_ios_project.rb
```
