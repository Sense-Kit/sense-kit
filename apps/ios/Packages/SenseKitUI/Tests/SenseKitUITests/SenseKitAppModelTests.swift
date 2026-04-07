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

        await model.load()

        #expect(model.endpointURLText == "https://example.ts.net/hooks/sensekit")
        #expect(model.bearerToken == "token-1")
        #expect(model.hmacSecret == "secret-1")
        #expect(model.drivingLocationBoostEnabled)
        #expect(model.timelineEntries.count == 1)
        #expect(model.auditEntries.count == 1)
        #expect(model.connectionStatus == "Configured for example.ts.net")
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

    init(initialState: SenseKitLoadedState) {
        self.currentState = initialState
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

    func setNextLoadedState(_ state: SenseKitLoadedState) {
        currentState = state
    }
}
