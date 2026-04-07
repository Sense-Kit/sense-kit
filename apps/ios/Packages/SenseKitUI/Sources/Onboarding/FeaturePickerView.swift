import SwiftUI
import SenseKitRuntime

public struct FeaturePickerView: View {
    @Bindable var model: SenseKitAppModel
    @FocusState private var focusedField: Field?
    @State private var draftWakeEnabled = false
    @State private var draftDrivingEnabled = false
    @State private var draftFixedPlacesEnabled = false
    @State private var draftContinuousLocationEnabled = false
    @State private var draftWorkoutsEnabled = false
    @State private var showsMotionDetails = false
    @State private var showsPlaceDetails = false
    @State private var showsPlaceSetup = false
    @State private var showsHomePlaceEditor = false
    @State private var showsWorkPlaceEditor = false
    @State private var showsOpenClawChecklist = false
    @State private var hasLoadedDraft = false
    @State private var hasUnlockedFollowUp = false

    private enum Field: Hashable {
        case endpoint
        case hookToken
        case secret
        case homeSearch
        case workSearch
    }

    public init(model: SenseKitAppModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroSection

                if let feedback = model.feedback {
                    SetupFeedbackBanner(feedback: feedback)
                }

                rawInputSection

                if shouldShowFollowUp {
                    followUpSection
                }

                connectionSection
                inspirationSection
            }
            .padding(20)
        }
        .navigationTitle("Setup")
        .scrollDismissesKeyboard(.interactively)
        .task {
            syncDraftFromModelIfNeeded()
        }
    }

    private var heroSection: some View {
        SetupSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("What should your AI assistant receive?")
                    .font(.largeTitle.weight(.bold))

                Text("Choose the raw inputs SenseKit is allowed to share with OpenClaw. Start with the smallest set that feels useful, then expand once you trust the flow.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Text("SenseKit keeps the setup progressive: first pick the inputs, then handle only the permissions and place setup those choices actually need.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rawInputSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Raw Inputs",
                subtitle: "These choices drive what SenseKit prepares and what OpenClaw can react to."
            )

            motionSelectionCard
            placesSelectionCard

            SetupSelectionCard(
                icon: "figure.run",
                title: "Workouts",
                description: "Workout start and finish timing for follow-up flows.",
                permissions: "HealthKit workout read",
                rawPreview: "workout start/end context and recovery follow-up timing",
                examples: [
                    "workout_ended -> recovery prompt",
                    "workout_started -> avoid long distracting replies"
                ],
                isSelected: draftWorkoutsEnabled
            ) {
                draftWorkoutsEnabled.toggle()
            }

            Button {
                dismissInput()
                Task {
                    await model.applySetupSelections(
                        wakeEnabled: draftWakeEnabled,
                        drivingEnabled: draftDrivingEnabled,
                        fixedPlacesEnabled: draftFixedPlacesEnabled,
                        continuousLocationEnabled: draftContinuousLocationEnabled,
                        workoutsEnabled: draftWorkoutsEnabled
                    )
                    hasUnlockedFollowUp = true
                }
            } label: {
                HStack {
                    Text(selectionButtonTitle)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.16, green: 0.33, blue: 0.61))
            .disabled(model.isBusy)
        }
    }

    private var motionSelectionCard: some View {
        SetupSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "figure.walk.motion")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(hasMotionSelection ? Color(red: 0.16, green: 0.33, blue: 0.61) : .secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Motion")
                            .font(.headline)
                        Text("Start broad, then choose which motion-derived signals you actually want.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: hasMotionSelection ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundStyle(hasMotionSelection ? Color(red: 0.16, green: 0.33, blue: 0.61) : .secondary)
                }

                DisclosureGroup(
                    isExpanded: $showsMotionDetails,
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            SetupChoiceRow(
                                title: "Wake timing",
                                detail: "Best for actual wake-up detection and morning handoff flows.",
                                isSelected: draftWakeEnabled
                            ) {
                                draftWakeEnabled.toggle()
                            }

                            SetupChoiceRow(
                                title: "Driving state",
                                detail: "Best for commute mode and voice-safe behavior when you start moving in a vehicle.",
                                isSelected: draftDrivingEnabled
                            ) {
                                draftDrivingEnabled.toggle()
                            }

                            Text("Permission: Motion & Fitness")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    },
                    label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Choose motion types")
                                .font(.subheadline.weight(.semibold))
                            Text(motionSelectionSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                )
            }
        }
    }

    private var placesSelectionCard: some View {
        SetupSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "house.and.flag")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(hasPlaceSelection ? Color(red: 0.16, green: 0.33, blue: 0.61) : .secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Places")
                            .font(.headline)
                        Text("Choose whether SenseKit should understand fixed places, continuous location movement, or both.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: hasPlaceSelection ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundStyle(hasPlaceSelection ? Color(red: 0.16, green: 0.33, blue: 0.61) : .secondary)
                }

                DisclosureGroup(
                    isExpanded: $showsPlaceDetails,
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            SetupChoiceRow(
                                title: "Fixed places",
                                detail: "Arrival and departure events for saved places like home or work.",
                                isSelected: draftFixedPlacesEnabled
                            ) {
                                draftFixedPlacesEnabled.toggle()
                            }

                            SetupChoiceRow(
                                title: "Continuous location data",
                                detail: "Movement and significant location changes for commute timing and location-aware behavior.",
                                isSelected: draftContinuousLocationEnabled
                            ) {
                                draftContinuousLocationEnabled.toggle()
                            }

                            Text("Permissions: Always Location for fixed places, While Using for continuous location movement.")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    },
                    label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Choose place types")
                                .font(.subheadline.weight(.semibold))
                            Text(placeSelectionSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                )
            }
        }
    }

    private var followUpSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Next Steps",
                subtitle: "SenseKit now narrows setup to the permissions and details your chosen inputs need."
            )

            if hasMotionSelection {
                SetupSurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Motion", systemImage: "figure.walk.motion")
                            .font(.headline)
                        Text("Selected: \(motionSelectionSummary)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        LabeledContent("Status", value: model.wakeCollectorStatusText)
                        Text(model.wakeCollectorHelpText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button {
                            Task {
                                await model.refreshStatusNow()
                            }
                        } label: {
                            SetupActionLabel(
                                title: "Check Motion Permission",
                                isRunning: model.isRefreshingStatuses
                            )
                        }
                        .disabled(model.isBusy)
                    }
                }
            }

            if hasPlaceSelection {
                SetupSurfaceCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Places", systemImage: "house.and.flag")
                            .font(.headline)

                        Text("Selected: \(placeSelectionSummary)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if draftFixedPlacesEnabled {
                            VStack(alignment: .leading, spacing: 10) {
                                SetupChoiceRow(
                                    title: "Labels only",
                                    detail: "Recommended. OpenClaw receives home/work labels, not the exact coordinates.",
                                    isSelected: model.placeSharingMode == .labelsOnly
                                ) {
                                    Task {
                                        await model.setPlaceSharingMode(.labelsOnly)
                                    }
                                }

                                SetupChoiceRow(
                                    title: "Exact coordinates",
                                    detail: "OpenClaw also receives the saved home or work coordinates when SenseKit knows you are there.",
                                    isSelected: model.placeSharingMode == .preciseCoordinates
                                ) {
                                    Task {
                                        await model.setPlaceSharingMode(.preciseCoordinates)
                                    }
                                }
                            }

                            Text(placeSharingHelpText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        LabeledContent("Status", value: model.locationCollectorStatusText)
                        Text(model.locationCollectorHelpText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button {
                            Task {
                                await model.refreshStatusNow()
                            }
                        } label: {
                            SetupActionLabel(
                                title: "Check Location Permission",
                                isRunning: model.isRefreshingStatuses
                            )
                        }
                        .disabled(model.isBusy)

                        if draftFixedPlacesEnabled {
                            DisclosureGroup("Manage fixed places", isExpanded: $showsPlaceSetup) {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Add the fixed places SenseKit should watch. Today that means Home and Work.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 10) {
                                        if !showsHomePlaceEditor {
                                            Button("Add Home") {
                                                showsHomePlaceEditor = true
                                            }
                                            .buttonStyle(.bordered)
                                        }

                                        if !showsWorkPlaceEditor {
                                            Button("Add Work") {
                                                showsWorkPlaceEditor = true
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }

                                    if !showsHomePlaceEditor && !showsWorkPlaceEditor {
                                        Text("No fixed places added yet.")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    if showsHomePlaceEditor {
                                        Divider()

                                        placeRegionEditor(
                                            title: "Home",
                                            summary: model.homeRegionSummary,
                                            radiusMeters: $model.homeRadiusMeters,
                                            searchQuery: $model.homeSearchQuery,
                                            searchField: .homeSearch,
                                            useCurrentLocationAction: {
                                                await model.setHomeRegionFromCurrentLocation()
                                            },
                                            searchAction: {
                                                await model.searchHomeRegionFromAddress()
                                            },
                                            clearAction: {
                                                await model.clearHomeRegion()
                                                showsHomePlaceEditor = false
                                            },
                                            isCapturing: model.isCapturingHomeRegion,
                                            isSearching: model.isSearchingHomeRegion
                                        )
                                    }

                                    if showsWorkPlaceEditor {
                                        Divider()

                                        placeRegionEditor(
                                            title: "Work",
                                            summary: model.workRegionSummary,
                                            radiusMeters: $model.workRadiusMeters,
                                            searchQuery: $model.workSearchQuery,
                                            searchField: .workSearch,
                                            useCurrentLocationAction: {
                                                await model.setWorkRegionFromCurrentLocation()
                                            },
                                            searchAction: {
                                                await model.searchWorkRegionFromAddress()
                                            },
                                            clearAction: {
                                                await model.clearWorkRegion()
                                                showsWorkPlaceEditor = false
                                            },
                                            isCapturing: model.isCapturingWorkRegion,
                                            isSearching: model.isSearchingWorkRegion
                                        )
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                }
            }

            if draftWorkoutsEnabled {
                SetupSurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Workouts", systemImage: "figure.run")
                            .font(.headline)
                        Text("Workout sharing is saved in the builder. The next runtime step is wiring the HealthKit permission and collector behind this choice.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Inspiration: finish a workout and let OpenClaw switch into recovery mode, hydration reminders, or a short reflection flow.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Connect OpenClaw",
                subtitle: "This belongs in Setup now, so people can finish onboarding in one place."
            )

            SetupSurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Connection", systemImage: model.showsOpenClawSetupGuide ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                            .font(.headline)
                        Spacer()
                        Text(model.connectionStatus)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(model.showsOpenClawSetupGuide ? .orange : .green)
                    }

                    if model.showsOpenClawSetupGuide {
                        Text("If you opened the iPhone app before finishing the OpenClaw side, do these steps first.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        DisclosureGroup("Show OpenClaw + Tailscale steps", isExpanded: $showsOpenClawChecklist) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(model.openClawSetupSteps.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("\(index + 1).")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Text(step)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }

                        Text("Use the private Tailscale HTTPS hook URL here. Do not paste a public Gateway port.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("OpenClaw is already configured. You can edit the fields below if the Gateway URL, hook token, or signing secret changes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Tailscale hook URL", text: $model.endpointURLText)
                            .setupTextFieldStyle(kind: .url)
                            .focused($focusedField, equals: .endpoint)

                        TextField("OpenClaw hook token", text: $model.bearerToken)
                            .setupTextFieldStyle()
                            .focused($focusedField, equals: .hookToken)

                        SecureField("SenseKit HMAC secret", text: $model.hmacSecret)
                            .setupTextFieldStyle()
                            .focused($focusedField, equals: .secret)
                    }

                    Button {
                        dismissInput()
                        Task {
                            await model.saveConnection()
                        }
                    } label: {
                        SetupActionLabel(
                            title: "Save OpenClaw Connection",
                            isRunning: model.isSavingConfiguration
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.12, green: 0.36, blue: 0.20))
                    .disabled(model.isBusy)

                    if !model.showsOpenClawSetupGuide {
                        Picker("Test Event", selection: $model.selectedTestEvent) {
                            Text("Wake Confirmed").tag(ContextEventType.wakeConfirmed)
                            Text("Driving Started").tag(ContextEventType.drivingStarted)
                            Text("Arrived Home").tag(ContextEventType.arrivedHome)
                            Text("Workout Ended").tag(ContextEventType.workoutEnded)
                        }

                        Button {
                            dismissInput()
                            Task {
                                await model.sendTestEvent()
                            }
                        } label: {
                            SetupActionLabel(
                                title: "Send Test Event",
                                isRunning: model.isSendingTestEvent
                            )
                        }
                        .disabled(model.isBusy)

                        Text("This uses the live queue, audit log, and OpenClaw delivery path so you can verify the whole path before waiting for a real event.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var inspirationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Inspiration",
                subtitle: "A few concrete setups so people can picture what is possible."
            )

            SetupSurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    InspirationExample(
                        title: "Gentle morning handoff",
                        setup: "Motion & Routine + labels-only place data",
                        result: "OpenClaw gets your wake signal first, then can wait for arrived_work before sending a heavier planning brief."
                    )

                    Divider()

                    InspirationExample(
                        title: "Private commute mode",
                        setup: "Motion & Routine + Places + exact home/work coordinates",
                        result: "OpenClaw can tell the difference between leaving home, driving, and arriving at work without needing you to trigger anything manually."
                    )

                    Divider()

                    InspirationExample(
                        title: "Post-workout recovery",
                        setup: "Workouts + labels-only place data",
                        result: "OpenClaw can switch into recovery prompts, hydration reminders, or a short check-in after the workout ends."
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func placeRegionEditor(
        title: String,
        summary: String,
        radiusMeters: Binding<Double>,
        searchQuery: Binding<String>,
        searchField: Field,
        useCurrentLocationAction: @escaping () async -> Void,
        searchAction: @escaping () async -> Void,
        clearAction: @escaping () async -> Void,
        isCapturing: Bool,
        isSearching: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            LabeledContent(title, value: summary)
            Stepper("\(title) radius: \(Int(radiusMeters.wrappedValue)) m", value: radiusMeters, in: 50...500, step: 25)

            Button {
                dismissInput()
                Task {
                    await useCurrentLocationAction()
                }
            } label: {
                SetupActionLabel(
                    title: "Use Current Location as \(title)",
                    isRunning: isCapturing
                )
            }
            .disabled(model.isBusy)

            TextField("Search \(title.lowercased()) address", text: searchQuery)
                .setupTextFieldStyle()
                .focused($focusedField, equals: searchField)
                .submitLabel(.search)
                .onSubmit {
                    dismissInput()
                    Task {
                        await searchAction()
                    }
                }

            Button {
                dismissInput()
                Task {
                    await searchAction()
                }
            } label: {
                SetupActionLabel(
                    title: "Search Address for \(title)",
                    isRunning: isSearching
                )
            }
            .disabled(model.isBusy || searchQuery.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Remove \(title)") {
                dismissInput()
                Task {
                    await clearAction()
                }
            }
            .disabled(model.isBusy || summary == "Not set")
        }
    }

    private var savedSelectionsExist: Bool {
        model.wakeSelectionEnabled
            || model.drivingSelectionEnabled
            || model.placesSelectionEnabled
            || model.drivingLocationBoostEnabled
            || model.workoutsSelectionEnabled
            || model.homeRegionSummary != "Not set"
            || model.workRegionSummary != "Not set"
    }

    private var draftMatchesSavedSelections: Bool {
        draftWakeEnabled == model.wakeSelectionEnabled
            && draftDrivingEnabled == model.drivingSelectionEnabled
            && draftFixedPlacesEnabled == model.placesSelectionEnabled
            && draftContinuousLocationEnabled == model.drivingLocationBoostEnabled
            && draftWorkoutsEnabled == model.workoutsSelectionEnabled
    }

    private var shouldShowFollowUp: Bool {
        hasUnlockedFollowUp || savedSelectionsExist
    }

    private var selectionButtonTitle: String {
        if draftMatchesSavedSelections {
            return shouldShowFollowUp ? "Selections Saved" : "Continue with These Inputs"
        }
        return "Continue with These Inputs"
    }

    private var placeSharingHelpText: String {
        switch model.placeSharingMode {
        case .labelsOnly:
            return "Recommended default. OpenClaw only receives place labels like home or work. Exact coordinates stay on the phone."
        case .preciseCoordinates:
            return "OpenClaw also receives the saved home or work coordinates when SenseKit knows you are in one of those places."
        }
    }

    private var hasPlaceSelection: Bool {
        draftFixedPlacesEnabled || draftContinuousLocationEnabled
    }

    private var placeSelectionSummary: String {
        switch (draftFixedPlacesEnabled, draftContinuousLocationEnabled) {
        case (true, true):
            return "Fixed places and continuous location data"
        case (true, false):
            return "Fixed places only"
        case (false, true):
            return "Continuous location data only"
        case (false, false):
            return "Nothing selected yet"
        }
    }

    private var hasMotionSelection: Bool {
        draftWakeEnabled || draftDrivingEnabled
    }

    private var motionSelectionSummary: String {
        switch (draftWakeEnabled, draftDrivingEnabled) {
        case (true, true):
            return "Wake timing and driving state"
        case (true, false):
            return "Wake timing only"
        case (false, true):
            return "Driving state only"
        case (false, false):
            return "Nothing selected yet"
        }
    }

    private func syncDraftFromModelIfNeeded() {
        guard !hasLoadedDraft else { return }
        draftWakeEnabled = model.wakeSelectionEnabled
        draftDrivingEnabled = model.drivingSelectionEnabled
        draftFixedPlacesEnabled = model.placesSelectionEnabled
        draftContinuousLocationEnabled = model.drivingLocationBoostEnabled
        draftWorkoutsEnabled = model.workoutsSelectionEnabled
        showsMotionDetails = hasMotionSelection
        showsPlaceDetails = hasPlaceSelection
        showsPlaceSetup = draftFixedPlacesEnabled && (model.homeRegionSummary != "Not set" || model.workRegionSummary != "Not set")
        showsHomePlaceEditor = model.homeRegionSummary != "Not set"
        showsWorkPlaceEditor = model.workRegionSummary != "Not set"
        showsOpenClawChecklist = model.showsOpenClawSetupGuide
        hasUnlockedFollowUp = savedSelectionsExist
        hasLoadedDraft = true
    }

    private func dismissInput() {
        focusedField = nil
    }

    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SetupSelectionCard: View {
    let icon: String
    let title: String
    let description: String
    let permissions: String
    let rawPreview: String
    let examples: [String]
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SetupSurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(isSelected ? Color(red: 0.16, green: 0.33, blue: 0.61) : .secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.headline)
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .imageScale(.large)
                            .foregroundStyle(isSelected ? Color(red: 0.16, green: 0.33, blue: 0.61) : .secondary)
                    }

                    Text("Asks for: \(permissions)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text("OpenClaw sees: \(rawPreview)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(examples, id: \.self) { example in
                            Label(example, systemImage: "sparkles")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SetupChoiceRow: View {
    let title: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 12)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundStyle(isSelected ? Color(red: 0.16, green: 0.33, blue: 0.61) : .secondary)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color(red: 0.16, green: 0.33, blue: 0.61).opacity(0.08) : Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SetupSurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

private struct InspirationExample: View {
    let title: String
    let setup: String
    let result: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text("Setup: \(setup)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            Text(result)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SetupActionLabel: View {
    let title: String
    let isRunning: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .fontWeight(.semibold)
            if isRunning {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct SetupFeedbackBanner: View {
    let feedback: SenseKitFeedback

    private var tint: Color {
        switch feedback.style {
        case .success:
            return .green
        case .error:
            return .red
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: feedback.style == .error ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(tint)
            Text(feedback.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }
}

private extension View {
    @ViewBuilder
    func setupTextFieldStyle(kind: SetupTextFieldKind = .plain) -> some View {
        #if os(iOS)
        switch kind {
        case .plain:
            self
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
        case .url:
            self
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
        }
        #else
        self
        #endif
    }
}

private enum SetupTextFieldKind {
    case plain
    case url
}
