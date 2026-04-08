import SwiftUI
import SenseKitUI

@main
struct SenseKitApp: App {
    @State private var model = SenseKitAppModel.live()

    var body: some Scene {
        WindowGroup {
            SenseKitRootView(model: model)
        }
    }
}
