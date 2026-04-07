import SwiftUI

public struct SenseKitRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: SenseKitAppModel

    public init(model: SenseKitAppModel = .preview) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        Group {
            if model.showsStartupScreen {
                StartupLoadingView(
                    title: model.startupTitle,
                    message: model.startupMessage,
                    isLoading: model.isBusy,
                    retry: {
                        Task {
                            await model.load()
                        }
                    }
                )
            } else {
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
        .task {
            await model.loadIfNeeded()
        }
        .task(id: scenePhase) {
            switch scenePhase {
            case .active:
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    await model.refreshState()
                }
            case .background:
                await model.persistRuntimeDraftOnBackground()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}

private struct StartupLoadingView: View {
    let title: String
    let message: String
    let isLoading: Bool
    let retry: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 0.93),
                    Color(red: 0.84, green: 0.90, blue: 0.84)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg.rectangle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(red: 0.12, green: 0.36, blue: 0.20))

                    Text(title)
                        .font(.title2.weight(.semibold))

                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(red: 0.12, green: 0.36, blue: 0.20))
                    Text("This can take a few seconds on phone startup.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Retry Startup") {
                        retry()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.12, green: 0.36, blue: 0.20))
                }
            }
            .padding(28)
            .frame(maxWidth: 420)
        }
    }
}
