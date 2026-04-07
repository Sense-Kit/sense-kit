import SwiftUI
import AppIntents
import SenseKitRuntime
import SenseKitUI

struct SenseKitAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [SenseKitRuntimeAppIntentsPackage.self]
    }
}

@main
struct SenseKitApp: App {
    @State private var model = SenseKitAppModel.live()

    var body: some Scene {
        WindowGroup {
            SenseKitRootView(model: model)
        }
    }
}
