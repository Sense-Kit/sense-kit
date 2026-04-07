import Foundation
import Observation
import SenseKitRuntime

public enum SettingsBusyAction: Sendable {
    case loading
    case savingConfiguration
    case sendingTestEvent
    case capturingHomeRegion
    case capturingWorkRegion
    case searchingHomeRegion
    case searchingWorkRegion
    case refreshingStatuses
}

@MainActor
@Observable
public final class SenseKitAppModel {
    public var selectedFeatures: Set<FeatureFlag>
    public var connectionStatus: String
    public var drivingLocationBoostEnabled: Bool
    public var placeSharingMode: PlaceSharingMode
    public var wakeCollectorStatus: WakeCollectorStatus
    public var locationCollectorStatus: LocationCollectorStatus
    public var timelineEntries: [DebugTimelineEntry]
    public var auditEntries: [AuditLogEntry]
    public var selectedTimelineServiceFilter: TimelineServiceFilter
    public var selectedAuditEventType: String?
    public var endpointURLText: String
    public var bearerToken: String
    public var hmacSecret: String
    public var homeSearchQuery: String
    public var workSearchQuery: String
    public var homeRadiusMeters: Double
    public var workRadiusMeters: Double
    public var selectedTestEvent: ContextEventType
    public var isBusy: Bool
    public var busyAction: SettingsBusyAction?
    public var errorMessage: String?
    public var feedback: SenseKitFeedback?
    public var lastStatusRefreshAt: Date?

    private let service: any SenseKitAppService
    private var configuration: RuntimeConfiguration
    private var hasLoaded = false

    public init(
        service: any SenseKitAppService,
        selectedFeatures: Set<FeatureFlag> = [.wakeBrief, .drivingMode],
        connectionStatus: String = "Not connected",
        drivingLocationBoostEnabled: Bool = false,
        placeSharingMode: PlaceSharingMode = .labelsOnly,
        wakeCollectorStatus: WakeCollectorStatus = .inactive,
        locationCollectorStatus: LocationCollectorStatus = .inactive,
        timelineEntries: [DebugTimelineEntry] = [],
        auditEntries: [AuditLogEntry] = [],
        selectedTimelineServiceFilter: TimelineServiceFilter = .all,
        selectedAuditEventType: String? = nil,
        endpointURLText: String = "",
        bearerToken: String = "",
        hmacSecret: String = "",
        homeSearchQuery: String = "",
        workSearchQuery: String = "",
        homeRadiusMeters: Double = 150,
        workRadiusMeters: Double = 150,
        selectedTestEvent: ContextEventType = .drivingStarted,
        isBusy: Bool = false,
        busyAction: SettingsBusyAction? = nil,
        errorMessage: String? = nil,
        feedback: SenseKitFeedback? = nil,
        lastStatusRefreshAt: Date? = nil,
        configuration: RuntimeConfiguration = RuntimeConfiguration(deviceID: "preview-device")
    ) {
        self.service = service
        self.selectedFeatures = selectedFeatures
        self.connectionStatus = connectionStatus
        self.drivingLocationBoostEnabled = drivingLocationBoostEnabled
        self.placeSharingMode = placeSharingMode
        self.wakeCollectorStatus = wakeCollectorStatus
        self.locationCollectorStatus = locationCollectorStatus
        self.timelineEntries = timelineEntries
        self.auditEntries = auditEntries
        self.selectedTimelineServiceFilter = selectedTimelineServiceFilter
        self.selectedAuditEventType = selectedAuditEventType
        self.endpointURLText = endpointURLText
        self.bearerToken = bearerToken
        self.hmacSecret = hmacSecret
        self.homeSearchQuery = homeSearchQuery
        self.workSearchQuery = workSearchQuery
        self.homeRadiusMeters = homeRadiusMeters
        self.workRadiusMeters = workRadiusMeters
        self.selectedTestEvent = selectedTestEvent
        self.isBusy = isBusy
        self.busyAction = busyAction
        self.errorMessage = errorMessage
        self.feedback = feedback
        self.lastStatusRefreshAt = lastStatusRefreshAt
        self.configuration = configuration
    }

    public func load() async {
        guard !isBusy else { return }
        isBusy = true
        busyAction = .loading
        defer {
            isBusy = false
            busyAction = nil
        }

        do {
            let state = try await service.loadState()
            apply(state)
            hasLoaded = true
            clearFeedback()
        } catch {
            setError(status: "Load failed", message: error.localizedDescription)
        }
    }

    public func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    public func refreshState() async {
        guard hasLoaded, !isBusy else { return }

        do {
            let state = try await service.loadState()
            apply(state, preserveDraftConfiguration: hasPendingConfigurationChanges(comparedTo: state.configuration))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func refreshStatusNow() async {
        guard hasLoaded, !isBusy else { return }
        isBusy = true
        busyAction = .refreshingStatuses
        defer {
            isBusy = false
            busyAction = nil
        }

        do {
            let state = try await service.loadState()
            apply(state, preserveDraftConfiguration: hasPendingConfigurationChanges(comparedTo: state.configuration))
            setSuccess(message: "Statuses refreshed.")
        } catch {
            setError(status: "Refresh failed", message: error.localizedDescription)
        }
    }

    public func saveConnection() async {
        guard !isBusy else { return }
        isBusy = true
        busyAction = .savingConfiguration
        defer {
            isBusy = false
            busyAction = nil
        }

        let endpoint = endpointURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        let bearer = bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = hmacSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        var nextConfiguration = configuration
        nextConfiguration.enabledFeatures = selectedFeatures
        nextConfiguration.drivingLocationBoostEnabled = drivingLocationBoostEnabled
        nextConfiguration.placeSharingMode = placeSharingMode

        if endpoint.isEmpty && bearer.isEmpty && secret.isEmpty {
            nextConfiguration.openClaw = nil
        } else {
            guard let url = URL(string: endpoint), let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) else {
                setError(status: "Invalid endpoint URL", message: "Enter a full http or https URL.")
                return
            }
            guard !bearer.isEmpty else {
                setError(status: "Bearer token required", message: "Enter the OpenClaw bearer token.")
                return
            }
            guard !secret.isEmpty else {
                setError(status: "HMAC secret required", message: "Enter the SenseKit HMAC secret.")
                return
            }

            nextConfiguration.openClaw = OpenClawConfiguration(
                endpointURL: url,
                bearerToken: bearer,
                hmacSecret: secret
            )
        }

        do {
            try await service.saveConfiguration(nextConfiguration)
            let state = try await service.loadState()
            apply(state)
            if nextConfiguration.openClaw == nil {
                setSuccess(message: "Configuration saved. OpenClaw delivery is off.")
            } else {
                setSuccess(message: "Configuration saved. OpenClaw is ready.")
            }
        } catch {
            setError(status: "Save failed", message: error.localizedDescription)
        }
    }

    public func sendTestEvent() async {
        guard !isBusy else { return }
        guard configuration.openClaw != nil else {
            setError(status: "Configure OpenClaw first", message: "Save the OpenClaw connection before sending a test event.")
            return
        }

        isBusy = true
        busyAction = .sendingTestEvent
        defer {
            isBusy = false
            busyAction = nil
        }

        do {
            try await service.sendTestEvent(selectedTestEvent)
            let state = try await service.loadState()
            apply(state)
            setSuccess(message: "Test event sent. Check Timeline and Audit for the result.")
        } catch {
            setError(status: "Test event failed", message: error.localizedDescription)
        }
    }

    public func toggleFeature(_ feature: FeatureFlag) async {
        if selectedFeatures.contains(feature) {
            selectedFeatures.remove(feature)
        } else {
            selectedFeatures.insert(feature)
        }

        await persistRuntimeConfigurationDraft(successMessage: "Feature selection saved.")
    }

    public func setDrivingLocationBoostEnabled(_ enabled: Bool) async {
        drivingLocationBoostEnabled = enabled
        await persistRuntimeConfigurationDraft(successMessage: "Driving location boost saved.")
    }

    public func applySetupSelections(
        motionAndRoutineEnabled: Bool,
        placesEnabled: Bool,
        workoutsEnabled: Bool
    ) async {
        var nextFeatures = selectedFeatures
        nextFeatures.subtract([.wakeBrief, .drivingMode, .homeWork, .workoutFollowUp])

        if motionAndRoutineEnabled {
            nextFeatures.insert(.wakeBrief)
            nextFeatures.insert(.drivingMode)
        }

        if placesEnabled {
            nextFeatures.insert(.homeWork)
        }

        if workoutsEnabled {
            nextFeatures.insert(.workoutFollowUp)
        }

        selectedFeatures = nextFeatures
        await persistRuntimeConfigurationDraft(successMessage: "Setup choices saved.")
    }

    public func setPlaceSharingMode(_ mode: PlaceSharingMode) async {
        placeSharingMode = mode
        await persistRuntimeConfigurationDraft(successMessage: "Place sharing updated.")
    }

    public func setHomeRegionFromCurrentLocation() async {
        await setRegionFromCurrentLocation(identifier: "home", radiusMeters: homeRadiusMeters, action: .capturingHomeRegion)
    }

    public func setWorkRegionFromCurrentLocation() async {
        await setRegionFromCurrentLocation(identifier: "work", radiusMeters: workRadiusMeters, action: .capturingWorkRegion)
    }

    public func searchHomeRegionFromAddress() async {
        await searchRegionFromAddress(
            query: homeSearchQuery,
            identifier: "home",
            radiusMeters: homeRadiusMeters,
            action: .searchingHomeRegion
        )
    }

    public func searchWorkRegionFromAddress() async {
        await searchRegionFromAddress(
            query: workSearchQuery,
            identifier: "work",
            radiusMeters: workRadiusMeters,
            action: .searchingWorkRegion
        )
    }

    public func clearHomeRegion() async {
        configuration.homeRegion = nil
        await persistRuntimeConfigurationDraft(successMessage: "Home region cleared.")
    }

    public func clearWorkRegion() async {
        configuration.workRegion = nil
        await persistRuntimeConfigurationDraft(successMessage: "Work region cleared.")
    }

    public func persistRuntimeDraftOnBackground() async {
        guard hasLoaded, !isBusy else { return }
        await persistRuntimeConfigurationDraft(successMessage: nil)
    }

    public static var preview: SenseKitAppModel {
        let previewState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(
                deviceID: "preview-device",
                enabledFeatures: [.wakeBrief, .drivingMode, .homeWork],
                drivingLocationBoostEnabled: true,
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://gateway.example/hooks/sensekit")!,
                    bearerToken: "preview-token",
                    hmacSecret: "preview-secret"
                )
            ),
            wakeCollectorStatus: .running,
            locationCollectorStatus: .running,
            timelineEntries: [
                DebugTimelineEntry(createdAt: Date(), category: .signal, message: "Received signal motion.automotive_entered"),
                DebugTimelineEntry(createdAt: Date(), category: .event, message: "Emitted driving_started")
            ],
            auditEntries: [
                AuditLogEntry(
                    createdAt: Date(),
                    eventType: "driving_started",
                    destination: "https://gateway.example/hooks/sensekit",
                    status: .delivered,
                    payloadSummary: "HTTP 200",
                    retryCount: 0
                )
            ]
        )

        let model = SenseKitAppModel(service: PreviewSenseKitAppService(state: previewState))
        model.apply(previewState)
        model.hasLoaded = true
        return model
    }

    public var filteredTimelineEntries: [DebugTimelineEntry] {
        timelineEntries.filter { selectedTimelineServiceFilter.includes($0) }
    }

    public var availableTimelineServiceFilters: [TimelineServiceFilter] {
        TimelineServiceFilter.availableFilters(for: timelineEntries)
    }

    public var filteredAuditEntries: [AuditLogEntry] {
        guard let selectedAuditEventType, !selectedAuditEventType.isEmpty else {
            return auditEntries
        }
        return auditEntries.filter { $0.eventType == selectedAuditEventType }
    }

    public var availableAuditEventTypes: [String] {
        AuditEventFilter.availableEventTypes(for: auditEntries)
    }

    public static func live() -> SenseKitAppModel {
        do {
            return SenseKitAppModel(service: try SenseKitAppEnvironment.makeLiveService())
        } catch {
            let model = SenseKitAppModel.preview
            model.setError(status: "Runtime init failed", message: error.localizedDescription)
            return model
        }
    }

    private func apply(_ state: SenseKitLoadedState, preserveDraftConfiguration: Bool = false) {
        if !preserveDraftConfiguration {
            configuration = state.configuration
        }

        lastStatusRefreshAt = Date()
        wakeCollectorStatus = state.wakeCollectorStatus
        locationCollectorStatus = state.locationCollectorStatus
        timelineEntries = state.timelineEntries
        auditEntries = state.auditEntries
        connectionStatus = Self.connectionStatus(for: state.configuration)

        if !availableTimelineServiceFilters.contains(selectedTimelineServiceFilter) {
            selectedTimelineServiceFilter = .all
        }

        if let selectedAuditEventType, !availableAuditEventTypes.contains(selectedAuditEventType) {
            self.selectedAuditEventType = nil
        }

        guard !preserveDraftConfiguration else {
            return
        }

        selectedFeatures = state.configuration.enabledFeatures
        drivingLocationBoostEnabled = state.configuration.drivingLocationBoostEnabled
        placeSharingMode = state.configuration.placeSharingMode
        endpointURLText = state.configuration.openClaw?.endpointURL.absoluteString ?? ""
        bearerToken = state.configuration.openClaw?.bearerToken ?? ""
        hmacSecret = state.configuration.openClaw?.hmacSecret ?? ""
        homeRadiusMeters = state.configuration.homeRegion?.radiusMeters ?? homeRadiusMeters
        workRadiusMeters = state.configuration.workRegion?.radiusMeters ?? workRadiusMeters
    }

    private func clearFeedback() {
        feedback = nil
        errorMessage = nil
    }

    private func setSuccess(message: String) {
        feedback = SenseKitFeedback(style: .success, message: message)
        errorMessage = nil
    }

    private func setError(status: String, message: String) {
        connectionStatus = status
        feedback = SenseKitFeedback(style: .error, message: message)
        errorMessage = message
    }

    private static func connectionStatus(for configuration: RuntimeConfiguration) -> String {
        guard let openClaw = configuration.openClaw else {
            return "Not connected"
        }

        if let host = openClaw.endpointURL.host(), !host.isEmpty {
            return "Configured for \(host)"
        }

        return "Configured"
    }

    public var wakeCollectorStatusText: String {
        switch wakeCollectorStatus {
        case .inactive:
            return "Motion export is off"
        case .permissionRequired:
            return "Needs Motion access"
        case .permissionDenied:
            return "Motion access denied"
        case .unavailable:
            return "Motion unavailable"
        case .running:
            return "Running"
        }
    }

    public var wakeCollectorHelpText: String {
        switch wakeCollectorStatus {
        case .inactive:
            return "Turn on Wake Brief in Setup, then save your settings to start exporting raw motion activity."
        case .permissionRequired:
            return "Allow Motion access when iPhone asks. SenseKit will send raw motion activity changes to OpenClaw."
        case .permissionDenied:
            return "Turn Motion & Fitness back on in iPhone Settings if you want raw motion activity export."
        case .unavailable:
            return "This device does not expose the motion activity API SenseKit needs for raw motion export."
        case .running:
            return "Motion updates are active. SenseKit will export raw motion activity changes to OpenClaw."
        }
    }

    public var locationCollectorStatusText: String {
        switch locationCollectorStatus {
        case .inactive:
            return "Location collection is off"
        case .configurationRequired:
            return "Home or Work needs setup"
        case .permissionRequired:
            return "Needs Location access"
        case .permissionDenied:
            return "Location access denied"
        case .unavailable:
            return "Location unavailable"
        case .running:
            return "Running"
        }
    }

    public var locationCollectorHelpText: String {
        switch locationCollectorStatus {
        case .inactive:
            return "Turn on the driving location boost or configure Home / Work to start location collection."
        case .configurationRequired:
            return "Save at least one Home or Work region, then tap Save Configuration."
        case .permissionRequired:
            return "Current Location capture starts with While Using the App. After you save Home or Work, iPhone should also ask for Always Allow so background geofences can work."
        case .permissionDenied:
            return "Turn Location access back on in iPhone Settings if you want place detection or driving location boosts."
        case .unavailable:
            return "This device does not expose the location services SenseKit needs."
        case .running:
            return "Location monitoring is active. SenseKit can now observe region entries and movement-based location boosts."
        }
    }

    public var statusRefreshText: String {
        guard let lastStatusRefreshAt else {
            return "Status not checked yet"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last checked \(formatter.localizedString(for: lastStatusRefreshAt, relativeTo: Date()))"
    }

    public var isSavingConfiguration: Bool { busyAction == .savingConfiguration }
    public var isSendingTestEvent: Bool { busyAction == .sendingTestEvent }
    public var isCapturingHomeRegion: Bool { busyAction == .capturingHomeRegion }
    public var isCapturingWorkRegion: Bool { busyAction == .capturingWorkRegion }
    public var isSearchingHomeRegion: Bool { busyAction == .searchingHomeRegion }
    public var isSearchingWorkRegion: Bool { busyAction == .searchingWorkRegion }
    public var isRefreshingStatuses: Bool { busyAction == .refreshingStatuses }

    public var homeRegionSummary: String {
        Self.regionSummary(configuration.homeRegion)
    }

    public var workRegionSummary: String {
        Self.regionSummary(configuration.workRegion)
    }

    public var motionAndRoutineSelectionEnabled: Bool {
        selectedFeatures.contains(.wakeBrief) || selectedFeatures.contains(.drivingMode)
    }

    public var placesSelectionEnabled: Bool {
        selectedFeatures.contains(.homeWork)
    }

    public var workoutsSelectionEnabled: Bool {
        selectedFeatures.contains(.workoutFollowUp)
    }

    public var showsOpenClawSetupGuide: Bool {
        configuration.openClaw == nil
    }

    public var openClawSetupSteps: [String] {
        guard showsOpenClawSetupGuide else {
            return []
        }

        return [
            "Add a SenseKit hook to your OpenClaw JSON and create a separate hooks token for it.",
            "Keep OpenClaw private and expose it with Tailscale Serve instead of opening the raw Gateway port to the internet.",
            "Paste the Tailscale hook URL, the hook token, and the SenseKit HMAC secret below, then save the connection."
        ]
    }

    public var showsStartupScreen: Bool {
        !hasLoaded
    }

    public var startupTitle: String {
        if let errorMessage, !errorMessage.isEmpty {
            return "Startup Problem"
        }
        return hasLoaded ? "SenseKit Ready" : "Starting SenseKit"
    }

    public var startupMessage: String {
        if let errorMessage, !errorMessage.isEmpty {
            return errorMessage
        }
        if hasLoaded {
            return "The local runtime is ready."
        }
        return "Opening the local runtime, loading saved events, and checking motion and location collectors."
    }

    private func hasPendingConfigurationChanges(comparedTo configuration: RuntimeConfiguration) -> Bool {
        if selectedFeatures != configuration.enabledFeatures {
            return true
        }

        if drivingLocationBoostEnabled != configuration.drivingLocationBoostEnabled {
            return true
        }

        if placeSharingMode != configuration.placeSharingMode {
            return true
        }

        if self.configuration.homeRegion != configuration.homeRegion {
            return true
        }

        if self.configuration.workRegion != configuration.workRegion {
            return true
        }

        let savedEndpoint = configuration.openClaw?.endpointURL.absoluteString ?? ""
        if endpointURLText != savedEndpoint {
            return true
        }

        let savedBearer = configuration.openClaw?.bearerToken ?? ""
        if bearerToken != savedBearer {
            return true
        }

        let savedSecret = configuration.openClaw?.hmacSecret ?? ""
        return hmacSecret != savedSecret
    }

    private func setRegionFromCurrentLocation(identifier: String, radiusMeters: Double, action: SettingsBusyAction) async {
        guard !isBusy else { return }
        isBusy = true
        busyAction = action
        defer {
            isBusy = false
            busyAction = nil
        }

        do {
            let region = try await service.captureCurrentRegion(identifier: identifier, radiusMeters: radiusMeters)
            let message = identifier == "home" ? "Home region updated and saved." : "Work region updated and saved."
            await applyRegion(region, successMessage: message)
        } catch {
            setError(status: "Location capture failed", message: error.localizedDescription)
        }
    }

    private func searchRegionFromAddress(
        query: String,
        identifier: String,
        radiusMeters: Double,
        action: SettingsBusyAction
    ) async {
        guard !isBusy else { return }
        isBusy = true
        busyAction = action
        defer {
            isBusy = false
            busyAction = nil
        }

        do {
            let region = try await service.searchRegion(query: query, identifier: identifier, radiusMeters: radiusMeters)
            let message = identifier == "home" ? "Home region found and saved." : "Work region found and saved."
            await applyRegion(region, successMessage: message)
        } catch {
            setError(status: "Address search failed", message: error.localizedDescription)
        }
    }

    private func applyRegion(_ region: RegionConfiguration, successMessage: String) async {
        selectedFeatures.insert(.homeWork)

        if region.identifier == "home" {
            configuration.homeRegion = region
            homeRadiusMeters = region.radiusMeters
        } else {
            configuration.workRegion = region
            workRadiusMeters = region.radiusMeters
        }

        await persistRuntimeConfigurationDraft(successMessage: successMessage)
    }

    private func persistRuntimeConfigurationDraft(successMessage: String?) async {
        let wasBusy = isBusy
        let previousAction = busyAction

        if !wasBusy {
            isBusy = true
            busyAction = .savingConfiguration
        }

        defer {
            if !wasBusy {
                isBusy = false
                busyAction = nil
            } else {
                busyAction = previousAction
            }
        }

        do {
            let nextConfiguration = draftRuntimeConfiguration()
            try await service.saveConfiguration(nextConfiguration)
            configuration = nextConfiguration
            if let successMessage {
                setSuccess(message: successMessage)
            }
        } catch {
            setError(status: "Save failed", message: error.localizedDescription)
        }
    }

    private func draftRuntimeConfiguration() -> RuntimeConfiguration {
        var nextConfiguration = configuration
        nextConfiguration.enabledFeatures = selectedFeatures
        nextConfiguration.drivingLocationBoostEnabled = drivingLocationBoostEnabled
        nextConfiguration.placeSharingMode = placeSharingMode

        if var homeRegion = nextConfiguration.homeRegion {
            homeRegion.radiusMeters = homeRadiusMeters
            nextConfiguration.homeRegion = homeRegion
        }

        if var workRegion = nextConfiguration.workRegion {
            workRegion.radiusMeters = workRadiusMeters
            nextConfiguration.workRegion = workRegion
        }

        return nextConfiguration
    }

    private static func regionSummary(_ region: RegionConfiguration?) -> String {
        guard let region else {
            return "Not set"
        }

        return String(
            format: "%.5f, %.5f · %.0f m",
            locale: Locale(identifier: "en_US_POSIX"),
            region.latitude,
            region.longitude,
            region.radiusMeters
        )
    }
}

private actor PreviewSenseKitAppService: SenseKitAppService {
    private let state: SenseKitLoadedState

    init(state: SenseKitLoadedState) {
        self.state = state
    }

    func loadState() async throws -> SenseKitLoadedState {
        state
    }

    func saveConfiguration(_ configuration: RuntimeConfiguration) async throws {}

    func sendTestEvent(_ eventType: ContextEventType) async throws {}

    func captureCurrentRegion(identifier: String, radiusMeters: Double) async throws -> RegionConfiguration {
        RegionConfiguration(identifier: identifier, latitude: 47.3769, longitude: 8.5417, radiusMeters: radiusMeters)
    }

    func searchRegion(query: String, identifier: String, radiusMeters: Double) async throws -> RegionConfiguration {
        RegionConfiguration(identifier: identifier, latitude: 47.3769, longitude: 8.5417, radiusMeters: radiusMeters)
    }
}
