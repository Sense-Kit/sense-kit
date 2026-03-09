import SwiftUI
import AppIntents
import SenseKitRuntime
import SenseKitUI

struct SenseKitBenchAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [SenseKitRuntimeAppIntentsPackage.self]
    }
}

@main
struct SenseKitBenchApp: App {
    var body: some Scene {
        WindowGroup {
            SenseKitRootView(model: .preview)
        }
    }
}
