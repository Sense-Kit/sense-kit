import Foundation
import Testing
@testable import SenseKitUI
import SenseKitRuntime

@MainActor
struct SenseKitAppModelTests {
    @Test
    func loadCopiesConfigurationAndEntriesFromService() async throws {
        let state = SenseKitLoadedState(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.wakeBrief, .drivingMode],
                drivingLocationBoostEnabled: true,
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://example.ts.net/hooks/sensekit")!,
                    bearerToken: "token-1",
                    hmacSecret: "secret-1"
                )
            ),
            wakeCollectorStatus: .running,
            locationCollectorStatus: .running,
            timelineEntries: [
                DebugTimelineEntry(createdAt: Date(), category: .event, message: "Manual test event driving_started")
            ],
            auditEntries: [
                AuditLogEntry(
                    createdAt: Date(),
                    eventType: "driving_started",
                    destination: "https://example.ts.net/hooks/sensekit",
                    status: .delivered,
                    payloadSummary: "HTTP 200",
                    retryCount: 0
                )
            ]
        )
        let service = FakeSenseKitAppService(initialState: state)
        let model = SenseKitAppModel(service: service)

        #expect(model.showsStartupScreen)

        await model.load()

        #expect(!model.showsStartupScreen)
        #expect(model.endpointURLText == "https://example.ts.net/hooks/sensekit")
        #expect(model.bearerToken == "token-1")
        #expect(model.hmacSecret == "secret-1")
        #expect(model.drivingLocationBoostEnabled)
        #expect(model.wakeCollectorStatus == .running)
        #expect(model.wakeCollectorStatusText == "Running")
        #expect(model.locationCollectorStatus == .running)
        #expect(model.locationCollectorStatusText == "Running")
        #expect(model.timelineEntries.count == 1)
        #expect(model.auditEntries.count == 1)
        #expect(model.connectionStatus == "Configured for example.ts.net")
        #expect(model.lastStatusRefreshAt != nil)
    }

    @Test
    func saveConnectionPersistsConfiguration() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1"))
        )
        let model = SenseKitAppModel(service: service)
        model.endpointURLText = "https://example.ts.net/hooks/sensekit"
        model.bearerToken = "token-2"
        model.hmacSecret = "secret-2"
        model.selectedFeatures = [.wakeBrief, .drivingMode]
        model.drivingLocationBoostEnabled = true

        await model.saveConnection()

        let savedConfiguration = await service.savedConfigurations.last
        #expect(savedConfiguration?.openClaw?.endpointURL.absoluteString == "https://example.ts.net/hooks/sensekit")
        #expect(savedConfiguration?.openClaw?.bearerToken == "token-2")
        #expect(savedConfiguration?.openClaw?.hmacSecret == "secret-2")
        #expect(savedConfiguration?.drivingLocationBoostEnabled == true)
        #expect(savedConfiguration?.enabledFeatures == [.wakeBrief, .drivingMode])
        #expect(model.feedback?.style == .success)
        #expect(model.feedback?.message == "Configuration saved. OpenClaw is ready.")
    }

    @Test
    func toggleFeaturePersistsConfigurationImmediately() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.wakeBrief])
            )
        )
        let model = SenseKitAppModel(service: service)
        await model.load()

        await model.toggleFeature(.homeWork)

        let savedConfiguration = await service.savedConfigurations.last
        #expect(model.selectedFeatures.contains(.homeWork))
        #expect(savedConfiguration?.enabledFeatures.contains(.homeWork) == true)
        #expect(model.feedback?.message == "Feature selection saved.")
    }

    @Test
    func setDrivingLocationBoostEnabledPersistsConfigurationImmediately() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.drivingMode])
            )
        )
        let model = SenseKitAppModel(service: service)
        await model.load()

        await model.setDrivingLocationBoostEnabled(true)

        let savedConfiguration = await service.savedConfigurations.last
        #expect(model.drivingLocationBoostEnabled)
        #expect(savedConfiguration?.drivingLocationBoostEnabled == true)
        #expect(model.feedback?.message == "Driving location boost saved.")
    }

    @Test
    func saveConnectionWithoutOpenClawShowsLocalOnlyMessage() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1"))
        )
        let model = SenseKitAppModel(service: service)
        model.selectedFeatures = [.homeWork]

        await model.saveConnection()

        #expect(model.feedback?.style == .success)
        #expect(model.feedback?.message == "Configuration saved. OpenClaw delivery is off.")
    }

    @Test
    func sendTestEventCallsServiceAndRefreshesEntries() async throws {
        let initialState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://example.ts.net/hooks/sensekit")!,
                    bearerToken: "token-3",
                    hmacSecret: "secret-3"
                )
            )
        )
        let refreshedState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://example.ts.net/hooks/sensekit")!,
                    bearerToken: "token-3",
                    hmacSecret: "secret-3"
                )
            ),
            timelineEntries: [
                DebugTimelineEntry(createdAt: Date(), category: .event, message: "Manual test event driving_started")
            ],
            auditEntries: [
                AuditLogEntry(
                    createdAt: Date(),
                    eventType: "driving_started",
                    destination: "https://example.ts.net/hooks/sensekit",
                    status: .delivered,
                    payloadSummary: "HTTP 200",
                    retryCount: 0
                )
            ]
        )
        let service = FakeSenseKitAppService(initialState: initialState)
        let model = SenseKitAppModel(service: service)
        await model.load()
        model.selectedTestEvent = .drivingStarted
        await service.setNextLoadedState(refreshedState)

        await model.sendTestEvent()

        let sentEvents = await service.sentTestEvents
        #expect(sentEvents == [.drivingStarted])
        #expect(model.timelineEntries.count == 1)
        #expect(model.auditEntries.count == 1)
        #expect(model.feedback?.style == .success)
        #expect(model.feedback?.message == "Test event sent. Check Timeline and Audit for the result.")
    }

    @Test
    func saveConnectionShowsMeaningfulValidationError() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1"))
        )
        let model = SenseKitAppModel(service: service)
        model.endpointURLText = "not-a-url"
        model.bearerToken = "token-2"
        model.hmacSecret = "secret-2"

        await model.saveConnection()

        #expect(model.connectionStatus == "Invalid endpoint URL")
        #expect(model.feedback?.style == .error)
        #expect(model.feedback?.message == "Enter a full http or https URL.")
    }

    @Test
    func sendTestEventWithoutConfigurationShowsMeaningfulError() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1"))
        )
        let model = SenseKitAppModel(service: service)

        await model.sendTestEvent()

        let sentEvents = await service.sentTestEvents
        #expect(sentEvents.isEmpty)
        #expect(model.connectionStatus == "Configure OpenClaw first")
        #expect(model.feedback?.style == .error)
        #expect(model.feedback?.message == "Save the OpenClaw connection before sending a test event.")
    }

    @Test
    func refreshStateReloadsTimelineAndAuditEntriesAfterInitialLoad() async throws {
        let initialState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(deviceID: "device-1"),
            timelineEntries: [
                DebugTimelineEntry(createdAt: Date(), category: .evaluation, message: "Runtime bootstrap completed")
            ],
            auditEntries: []
        )
        let refreshedState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(deviceID: "device-1"),
            timelineEntries: [
                DebugTimelineEntry(createdAt: Date(), category: .signal, message: "Received raw motion activity walking")
            ],
            auditEntries: [
                AuditLogEntry(
                    createdAt: Date(),
                    eventType: "motion_activity_observed",
                    destination: "https://example.ts.net/hooks/sensekit",
                    status: .delivered,
                    payloadSummary: "HTTP 200",
                    retryCount: 0
                )
            ]
        )
        let service = FakeSenseKitAppService(initialState: initialState)
        let model = SenseKitAppModel(service: service)

        await model.load()
        await service.setNextLoadedState(refreshedState)

        await model.refreshState()

        #expect(model.timelineEntries.count == 1)
        #expect(model.timelineEntries.first?.message == "Received raw motion activity walking")
        #expect(model.auditEntries.count == 1)
        #expect(model.auditEntries.first?.eventType == "motion_activity_observed")
    }

    @Test
    func refreshStateDoesNotOverwriteUnsavedFeatureSelections() async throws {
        let initialState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.wakeBrief]
            )
        )
        let refreshedState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.wakeBrief]
            ),
            timelineEntries: [
                DebugTimelineEntry(createdAt: Date(), category: .evaluation, message: "Background refresh")
            ]
        )
        let service = FakeSenseKitAppService(initialState: initialState)
        let model = SenseKitAppModel(service: service)

        await model.load()
        model.selectedFeatures.insert(.homeWork)
        await service.setNextLoadedState(refreshedState)

        await model.refreshState()

        #expect(model.selectedFeatures.contains(.wakeBrief))
        #expect(model.selectedFeatures.contains(.homeWork))
        #expect(model.timelineEntries.count == 1)
        #expect(model.timelineEntries.first?.message == "Background refresh")
    }

    @Test
    func refreshStateDoesNotOverwriteUnsavedConnectionDrafts() async throws {
        let initialState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.wakeBrief, .drivingMode],
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://saved.ts.net/hooks/sensekit")!,
                    bearerToken: "saved-token",
                    hmacSecret: "saved-secret"
                )
            )
        )
        let refreshedState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.wakeBrief, .drivingMode],
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://saved.ts.net/hooks/sensekit")!,
                    bearerToken: "saved-token",
                    hmacSecret: "saved-secret"
                )
            ),
            timelineEntries: [
                DebugTimelineEntry(createdAt: Date(), category: .evaluation, message: "Background refresh")
            ]
        )
        let service = FakeSenseKitAppService(initialState: initialState)
        let model = SenseKitAppModel(service: service)

        await model.load()
        model.endpointURLText = "https://draft.ts.net/hooks/sensekit"
        model.bearerToken = "draft-token"
        model.hmacSecret = "draft-secret"
        await service.setNextLoadedState(refreshedState)

        await model.refreshState()

        #expect(model.endpointURLText == "https://draft.ts.net/hooks/sensekit")
        #expect(model.bearerToken == "draft-token")
        #expect(model.hmacSecret == "draft-secret")
        #expect(model.timelineEntries.count == 1)
        #expect(model.timelineEntries.first?.message == "Background refresh")
    }

    @Test
    func setHomeRegionFromCurrentLocationUpdatesDraftConfiguration() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.homeWork])
            ),
            nextCurrentRegion: RegionConfiguration(
                identifier: "home",
                latitude: 47.3769,
                longitude: 8.5417,
                radiusMeters: 175
            )
        )
        let model = SenseKitAppModel(service: service)

        await model.load()
        model.homeRadiusMeters = 175

        await model.setHomeRegionFromCurrentLocation()

        let capturedRequests = await service.captureRequests
        let savedConfiguration = await service.savedConfigurations.last
        #expect(capturedRequests.count == 1)
        #expect(capturedRequests.first?.0 == "home")
        #expect(capturedRequests.first?.1 == 175)
        #expect(model.homeRegionSummary.contains("47.37690"))
        #expect(model.feedback?.style == .success)
        #expect(model.feedback?.message == "Home region updated and saved.")
        #expect(savedConfiguration?.homeRegion?.identifier == "home")
        #expect(savedConfiguration?.enabledFeatures.contains(.homeWork) == true)
    }

    @Test
    func searchHomeRegionFromAddressUpdatesDraftConfiguration() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(deviceID: "device-1")
            ),
            nextSearchRegion: RegionConfiguration(
                identifier: "home",
                latitude: 47.42310,
                longitude: 8.54760,
                radiusMeters: 200
            )
        )
        let model = SenseKitAppModel(service: service)

        await model.load()
        model.homeSearchQuery = "Bahnhofstrasse 1 Zurich"
        model.homeRadiusMeters = 200

        await model.searchHomeRegionFromAddress()

        let searchRequests = await service.searchRequests
        let savedConfiguration = await service.savedConfigurations.last
        #expect(searchRequests.count == 1)
        #expect(searchRequests.first?.0 == "home")
        #expect(searchRequests.first?.1 == "Bahnhofstrasse 1 Zurich")
        #expect(searchRequests.first?.2 == 200)
        #expect(model.selectedFeatures.contains(.homeWork))
        #expect(model.homeRegionSummary.contains("47.42310"))
        #expect(model.feedback?.message == "Home region found and saved.")
        #expect(savedConfiguration?.homeRegion?.identifier == "home")
    }

    @Test
    func refreshStateUpdatesLastStatusRefreshAt() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1"))
        )
        let model = SenseKitAppModel(service: service)

        await model.load()
        let firstRefresh = try #require(model.lastStatusRefreshAt)

        try? await Task.sleep(for: .milliseconds(20))
        await model.refreshState()

        let secondRefresh = try #require(model.lastStatusRefreshAt)
        #expect(secondRefresh >= firstRefresh)
    }

    @Test
    func startupStatusTextExplainsCurrentLaunchState() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1"))
        )
        let model = SenseKitAppModel(service: service)

        #expect(model.startupTitle == "Starting SenseKit")
        #expect(model.startupMessage == "Opening the local runtime, loading saved events, and checking motion and location collectors.")

        await model.load()

        #expect(model.startupTitle == "SenseKit Ready")
    }
}

struct EntryCopyFormatterTests {
    @Test
    func auditEntryCopyTextIncludesUsefulFields() {
        let entry = AuditLogEntry(
            createdAt: Date(timeIntervalSince1970: 1_775_520_000),
            eventType: "driving_started",
            destination: "https://example.ts.net/hooks/sensekit",
            status: .delivered,
            payloadSummary: "HTTP 200",
            retryCount: 0
        )

        let text = EntryCopyFormatter.auditEntry(entry)

        #expect(text.contains("type: audit"))
        #expect(text.contains("event_type: driving_started"))
        #expect(text.contains("status: delivered"))
        #expect(text.contains("destination: https://example.ts.net/hooks/sensekit"))
        #expect(text.contains("payload_summary: HTTP 200"))
    }

    @Test
    func timelineEntryCopyTextIncludesPayloadWhenPresent() {
        let entry = DebugTimelineEntry(
            createdAt: Date(timeIntervalSince1970: 1_775_520_000),
            category: .event,
            message: "Manual test event driving_started",
            payload: "score=0.70"
        )

        let text = EntryCopyFormatter.timelineEntry(entry)

        #expect(text.contains("type: timeline"))
        #expect(text.contains("category: event"))
        #expect(text.contains("message: Manual test event driving_started"))
        #expect(text.contains("payload: score=0.70"))
    }
}

private actor FakeSenseKitAppService: SenseKitAppService {
    private var currentState: SenseKitLoadedState
    private(set) var savedConfigurations: [RuntimeConfiguration] = []
    private(set) var sentTestEvents: [ContextEventType] = []
    private let currentRegionResult: RegionConfiguration?
    private let searchRegionResult: RegionConfiguration?
    private(set) var captureRequests: [(String, Double)] = []
    private(set) var searchRequests: [(String, String, Double)] = []

    init(
        initialState: SenseKitLoadedState,
        nextCurrentRegion: RegionConfiguration? = nil,
        nextSearchRegion: RegionConfiguration? = nil
    ) {
        self.currentState = initialState
        self.currentRegionResult = nextCurrentRegion
        self.searchRegionResult = nextSearchRegion
    }

    func loadState() async throws -> SenseKitLoadedState {
        currentState
    }

    func saveConfiguration(_ configuration: RuntimeConfiguration) async throws {
        savedConfigurations.append(configuration)
        currentState = SenseKitLoadedState(
            configuration: configuration,
            timelineEntries: currentState.timelineEntries,
            auditEntries: currentState.auditEntries
        )
    }

    func sendTestEvent(_ eventType: ContextEventType) async throws {
        sentTestEvents.append(eventType)
    }

    func captureCurrentRegion(identifier: String, radiusMeters: Double) async throws -> RegionConfiguration {
        captureRequests.append((identifier, radiusMeters))
        guard let currentRegionResult else {
            throw NSError(domain: "FakeSenseKitAppService", code: 1)
        }
        return currentRegionResult
    }

    func searchRegion(query: String, identifier: String, radiusMeters: Double) async throws -> RegionConfiguration {
        searchRequests.append((identifier, query, radiusMeters))
        guard let searchRegionResult else {
            throw NSError(domain: "FakeSenseKitAppService", code: 2)
        }
        return searchRegionResult
    }

    func setNextLoadedState(_ state: SenseKitLoadedState) {
        currentState = state
    }
}
