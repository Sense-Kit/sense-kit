import SwiftUI
import SenseKitUI

@main
struct SenseKitBenchApp: App {
    @State private var model = SenseKitAppModel.live()

    var body: some Scene {
        WindowGroup {
            SenseKitRootView(model: model)
        }
    }
}
