import SwiftUI

public struct SettingsView: View {
    @Bindable var model: SenseKitAppModel

    public init(model: SenseKitAppModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            Section("Connection") {
                LabeledContent("OpenClaw", value: model.connectionStatus)
            }

            Section("Driving") {
                Toggle("Improve with Location", isOn: $model.drivingLocationBoostEnabled)
                Text("Driving works without Location. This only improves confidence and timing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Boost Precision") {
                Label("Wake boost via Shortcuts", systemImage: "bolt.circle")
                Label("Workout boost via Shortcuts", systemImage: "bolt.circle")
                Label("Focus on/off via Shortcuts", systemImage: "bolt.circle")
            }
        }
        .navigationTitle("Settings")
    }
}
