import SwiftUI

public struct SenseKitRootView: View {
    @State private var model: SenseKitAppModel

    public init(model: SenseKitAppModel = .preview) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        TabView {
            NavigationStack {
                FeaturePickerView(model: model)
            }
            .tabItem {
                Label("Setup", systemImage: "slider.horizontal.3")
            }

            NavigationStack {
                DebugTimelineView(entries: model.timelineEntries)
            }
            .tabItem {
                Label("Timeline", systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                AuditLogView(entries: model.auditEntries)
            }
            .tabItem {
                Label("Audit", systemImage: "doc.text.magnifyingglass")
            }

            NavigationStack {
                SettingsView(model: model)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

