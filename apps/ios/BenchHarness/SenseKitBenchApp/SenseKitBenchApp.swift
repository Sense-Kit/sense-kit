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
    @State private var model = SenseKitAppModel.live()

    var body: some Scene {
        WindowGroup {
            SenseKitRootView(model: model)
        }
    }
}
