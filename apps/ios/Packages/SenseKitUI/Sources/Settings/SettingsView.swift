import SwiftUI
import SenseKitRuntime

public struct SettingsView: View {
    @Bindable var model: SenseKitAppModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case endpoint
        case bearer
        case homeSearch
        case workSearch
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

                Button("Save Configuration") {
                    dismissInput()
                    Task {
                        await model.saveConnection()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy)
                .overlay(alignment: .trailing) {
                    if model.isSavingConfiguration {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let feedback = model.feedback {
                    FeedbackBanner(feedback: feedback)
                }
            }

            Section("Driving") {
                Toggle(
                    "Improve with Location",
                    isOn: Binding(
                        get: { model.drivingLocationBoostEnabled },
                        set: { newValue in
                            Task {
                                await model.setDrivingLocationBoostEnabled(newValue)
                            }
                        }
                    )
                )
                Text("Driving works without Location. This only improves confidence and timing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Motion Activity Alpha") {
                LabeledContent("Motion collector", value: model.wakeCollectorStatusText)
                LabeledContent("Status checks", value: model.statusRefreshText)
                Button {
                    Task {
                        await model.refreshStatusNow()
                    }
                } label: {
                    ActionButtonLabel(
                        title: "Refresh Motion Status",
                        isRunning: model.isRefreshingStatuses
                    )
                }
                .disabled(model.isBusy)
                Text(model.wakeCollectorHelpText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Location Alpha") {
                LabeledContent("Location collector", value: model.locationCollectorStatusText)
                LabeledContent("Status checks", value: model.statusRefreshText)
                Button {
                    Task {
                        await model.refreshStatusNow()
                    }
                } label: {
                    ActionButtonLabel(
                        title: "Refresh Location Status",
                        isRunning: model.isRefreshingStatuses
                    )
                }
                .disabled(model.isBusy)
                Text(model.locationCollectorHelpText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !model.fixedPlaces.isEmpty {
                Section("Saved Places") {
                    ForEach(model.fixedPlaces, id: \.identifier) { place in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(place.displayName ?? place.identifier)
                                        .font(.subheadline.weight(.semibold))
                                    Text(placeSummary(place))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 12)

                                Button("Remove") {
                                    dismissInput()
                                    Task {
                                        await model.removeFixedPlace(identifier: place.identifier)
                                    }
                                }
                                .disabled(model.isBusy)
                            }
                        }
                    }

                    Text("Add new named places from Setup. This list shows the fixed places SenseKit is currently watching.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Home / Work") {
                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("Home", value: model.homeRegionSummary)
                    Stepper("Home radius: \(Int(model.homeRadiusMeters)) m", value: $model.homeRadiusMeters, in: 50...500, step: 25)
                    Button {
                        dismissInput()
                        Task {
                            await model.setHomeRegionFromCurrentLocation()
                        }
                    } label: {
                        ActionButtonLabel(
                            title: "Use Current Location as Home",
                            isRunning: model.isCapturingHomeRegion
                        )
                    }
                    .disabled(model.isBusy)

                    TextField("Search home address", text: $model.homeSearchQuery)
                        .addressTextEntryStyle()
                        .focused($focusedField, equals: Field.homeSearch)
                    Button {
                        dismissInput()
                        Task {
                            await model.searchHomeRegionFromAddress()
                        }
                    } label: {
                        ActionButtonLabel(
                            title: "Search Address for Home",
                            isRunning: model.isSearchingHomeRegion
                        )
                    }
                    .disabled(model.isBusy || model.homeSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Clear Home") {
                        dismissInput()
                        Task {
                            await model.clearHomeRegion()
                        }
                    }
                    .disabled(model.isBusy || model.homeRegionSummary == "Not set")
                }

                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("Work", value: model.workRegionSummary)
                    Stepper("Work radius: \(Int(model.workRadiusMeters)) m", value: $model.workRadiusMeters, in: 50...500, step: 25)
                    Button {
                        dismissInput()
                        Task {
                            await model.setWorkRegionFromCurrentLocation()
                        }
                    } label: {
                        ActionButtonLabel(
                            title: "Use Current Location as Work",
                            isRunning: model.isCapturingWorkRegion
                        )
                    }
                    .disabled(model.isBusy)

                    TextField("Search work address", text: $model.workSearchQuery)
                        .addressTextEntryStyle()
                        .focused($focusedField, equals: Field.workSearch)
                    Button {
                        dismissInput()
                        Task {
                            await model.searchWorkRegionFromAddress()
                        }
                    } label: {
                        ActionButtonLabel(
                            title: "Search Address for Work",
                            isRunning: model.isSearchingWorkRegion
                        )
                    }
                    .disabled(model.isBusy || model.workSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Clear Work") {
                        dismissInput()
                        Task {
                            await model.clearWorkRegion()
                        }
                    }
                    .disabled(model.isBusy || model.workRegionSummary == "Not set")
                }

                Text("You can stand at the place and use Current Location, or type a street or address and search for it. iPhone usually asks for While Using first, then asks for Always after you save Home or Work.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Passive Signals") {
                Label("Motion activity from Core Motion", systemImage: "figure.walk.motion")
                Label("Location changes from Core Location", systemImage: "location")
                Label("Power state from UIDevice", systemImage: "battery.100")
                Label("Workout samples from HealthKit", systemImage: "heart.text.square")
            }

            Section("Bench Test") {
                Picker("Signal Batch", selection: $model.selectedTestScenario) {
                    ForEach(testableScenarios, id: \.self) { scenario in
                        Text(label(for: scenario)).tag(scenario)
                    }
                }

                Button {
                    dismissInput()
                    Task {
                        await model.sendTestScenario()
                    }
                } label: {
                    ActionButtonLabel(
                        title: "Send Test Signal Batch",
                        isRunning: model.isSendingTestScenario
                    )
                }
                .disabled(model.isBusy || model.endpointURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Text("This sends a representative raw signal batch through the real queue, audit log, and OpenClaw delivery path.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                NavigationLink("Privacy Policy and Beta Notes") {
                    PrivacyPolicyView()
                }

                Text("This screen explains what the closed beta collects, what gets sent to OpenClaw, and how testers can turn collection off.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .settingsKeyboardDismissSupport(dismissInput)
    }

    private var testableScenarios: [SignalTestScenario] {
        [.wakeSignals, .drivingSignals, .placeArrival, .workoutFinished]
    }

    private func label(for scenario: SignalTestScenario) -> String {
        switch scenario {
        case .wakeSignals:
            return "Wake Signals"
        case .drivingSignals:
            return "Driving Signals"
        case .placeArrival:
            return "Place Arrival"
        case .workoutFinished:
            return "Workout Finished"
        }
    }

    private func dismissInput() {
        focusedField = nil
    }

    private func placeSummary(_ place: RegionConfiguration) -> String {
        let coordinateText = String(
            format: "%.5f, %.5f",
            locale: Locale(identifier: "en_US_POSIX"),
            place.latitude,
            place.longitude
        )
        return "\(coordinateText) · \(Int(place.radiusMeters)) m"
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
    func addressTextEntryStyle() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled(false)
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

private struct ActionButtonLabel: View {
    let title: String
    let isRunning: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if isRunning {
                ProgressView()
                    .controlSize(.small)
            }
        }
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
