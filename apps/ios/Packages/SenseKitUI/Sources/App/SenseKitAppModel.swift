import Foundation
import Observation
import SenseKitRuntime

@MainActor
@Observable
public final class SenseKitAppModel {
    public var selectedFeatures: Set<FeatureFlag>
    public var connectionStatus: String
    public var drivingLocationBoostEnabled: Bool
    public var timelineEntries: [DebugTimelineEntry]
    public var auditEntries: [AuditLogEntry]
    public var endpointURLText: String
    public var bearerToken: String
    public var hmacSecret: String
    public var selectedTestEvent: ContextEventType
    public var isBusy: Bool
    public var errorMessage: String?
    public var feedback: SenseKitFeedback?

    private let service: any SenseKitAppService
    private var configuration: RuntimeConfiguration
    private var hasLoaded = false

    public init(
        service: any SenseKitAppService,
        selectedFeatures: Set<FeatureFlag> = [.wakeBrief, .drivingMode],
        connectionStatus: String = "Not connected",
        drivingLocationBoostEnabled: Bool = false,
        timelineEntries: [DebugTimelineEntry] = [],
        auditEntries: [AuditLogEntry] = [],
        endpointURLText: String = "",
        bearerToken: String = "",
        hmacSecret: String = "",
        selectedTestEvent: ContextEventType = .drivingStarted,
        isBusy: Bool = false,
        errorMessage: String? = nil,
        feedback: SenseKitFeedback? = nil,
        configuration: RuntimeConfiguration = RuntimeConfiguration(deviceID: "preview-device")
    ) {
        self.service = service
        self.selectedFeatures = selectedFeatures
        self.connectionStatus = connectionStatus
        self.drivingLocationBoostEnabled = drivingLocationBoostEnabled
        self.timelineEntries = timelineEntries
        self.auditEntries = auditEntries
        self.endpointURLText = endpointURLText
        self.bearerToken = bearerToken
        self.hmacSecret = hmacSecret
        self.selectedTestEvent = selectedTestEvent
        self.isBusy = isBusy
        self.errorMessage = errorMessage
        self.feedback = feedback
        self.configuration = configuration
    }

    public func load() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

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

    public func saveConnection() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        let endpoint = endpointURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        let bearer = bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = hmacSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        var nextConfiguration = configuration
        nextConfiguration.enabledFeatures = selectedFeatures
        nextConfiguration.drivingLocationBoostEnabled = drivingLocationBoostEnabled

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
                setSuccess(message: "Configuration cleared. SenseKit will stop sending events.")
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
        defer { isBusy = false }

        do {
            try await service.sendTestEvent(selectedTestEvent)
            let state = try await service.loadState()
            apply(state)
            setSuccess(message: "Test event sent. Check Timeline and Audit for the result.")
        } catch {
            setError(status: "Test event failed", message: error.localizedDescription)
        }
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

    public static func live() -> SenseKitAppModel {
        do {
            return SenseKitAppModel(service: try SenseKitAppEnvironment.makeLiveService())
        } catch {
            let model = SenseKitAppModel.preview
            model.setError(status: "Runtime init failed", message: error.localizedDescription)
            return model
        }
    }

    private func apply(_ state: SenseKitLoadedState) {
        configuration = state.configuration
        selectedFeatures = state.configuration.enabledFeatures
        drivingLocationBoostEnabled = state.configuration.drivingLocationBoostEnabled
        timelineEntries = state.timelineEntries
        auditEntries = state.auditEntries
        endpointURLText = state.configuration.openClaw?.endpointURL.absoluteString ?? ""
        bearerToken = state.configuration.openClaw?.bearerToken ?? ""
        hmacSecret = state.configuration.openClaw?.hmacSecret ?? ""
        connectionStatus = Self.connectionStatus(for: state.configuration)
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
}
