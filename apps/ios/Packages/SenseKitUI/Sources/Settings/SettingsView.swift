import SwiftUI
import SenseKitRuntime

public struct SettingsView: View {
    @Bindable var model: SenseKitAppModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case endpoint
        case bearer
        case secret
    }

    public init(model: SenseKitAppModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            Section("Connection") {
                LabeledContent("OpenClaw", value: model.connectionStatus)
                TextField("Endpoint URL", text: $model.endpointURLText)
                    .connectionTextEntryStyle(isURL: true)
                    .focused($focusedField, equals: Field.endpoint)
                TextField("Bearer token", text: $model.bearerToken)
                    .connectionTextEntryStyle()
                    .focused($focusedField, equals: Field.bearer)
                SecureField("HMAC secret", text: $model.hmacSecret)
                    .connectionTextEntryStyle()
                    .focused($focusedField, equals: Field.secret)

                Button("Save Configuration") {
                    dismissInput()
                    Task {
                        await model.saveConnection()
                    }
                }
                .disabled(model.isBusy)

                if let feedback = model.feedback {
                    FeedbackBanner(feedback: feedback)
                }
            }

            Section("Driving") {
                Toggle("Improve with Location", isOn: $model.drivingLocationBoostEnabled)
                Text("Driving works without Location. This only improves confidence and timing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Motion Activity Alpha") {
                LabeledContent("Motion collector", value: model.wakeCollectorStatusText)
                Text(model.wakeCollectorHelpText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Boost Precision") {
                Label("Wake boost via Shortcuts", systemImage: "bolt.circle")
                Label("Workout boost via Shortcuts", systemImage: "bolt.circle")
                Label("Focus on/off via Shortcuts", systemImage: "bolt.circle")
            }

            Section("Bench Test") {
                Picker("Test Event", selection: $model.selectedTestEvent) {
                    ForEach(testableEvents, id: \.self) { eventType in
                        Text(label(for: eventType)).tag(eventType)
                    }
                }

                Button("Send Test Event") {
                    dismissInput()
                    Task {
                        await model.sendTestEvent()
                    }
                }
                .disabled(model.isBusy || model.endpointURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Text("This uses the real queue, audit log, and OpenClaw delivery path before passive collectors are wired.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .settingsKeyboardDismissSupport(dismissInput)
    }

    private var testableEvents: [ContextEventType] {
        [.wakeConfirmed, .drivingStarted, .arrivedHome, .workoutEnded]
    }

    private func label(for eventType: ContextEventType) -> String {
        switch eventType {
        case .wakeConfirmed:
            return "Wake Confirmed"
        case .drivingStarted:
            return "Driving Started"
        case .arrivedHome:
            return "Arrived Home"
        case .workoutEnded:
            return "Workout Ended"
        default:
            return eventType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func dismissInput() {
        focusedField = nil
    }
}

private extension View {
    @ViewBuilder
    func connectionTextEntryStyle(isURL: Bool = false) -> some View {
        #if os(iOS)
        if isURL {
            self
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()
        } else {
            self
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func settingsKeyboardDismissSupport(_ dismiss: @escaping () -> Void) -> some View {
        #if os(iOS)
        self
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        #else
        self
        #endif
    }
}

private struct FeedbackBanner: View {
    let feedback: SenseKitFeedback

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: feedback.style == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(feedback.style == .success ? .green : .orange)
            Text(feedback.message)
                .font(.footnote)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(feedback.message)
    }
}
