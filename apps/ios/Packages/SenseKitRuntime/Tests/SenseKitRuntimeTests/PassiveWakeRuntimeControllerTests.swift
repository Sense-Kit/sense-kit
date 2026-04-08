import Foundation
import XCTest
@testable import SenseKitRuntime

@MainActor
final class PassiveWakeRuntimeControllerTests: XCTestCase {
    func testRefreshStartsMotionCollectorWhenWakeFeatureEnabled() async throws {
        let store = ControllerTestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.wakeBrief])
        )
        let motionCollectorFactory = TestMotionCollectorFactory()
        let powerCollectorFactory = TestPowerCollectorFactory()
        let controller = PassiveWakeRuntimeController(
            store: store,
            settingsStore: settingsStore,
            deliveryClient: DeliveryClient(),
            clock: FixedClock(currentDate: date(hour: 6, minute: 45)),
            motionCollectorFactory: motionCollectorFactory,
            powerCollectorFactory: powerCollectorFactory,
            motionAuthorizationProvider: StubMotionAuthorizationProvider(status: .authorized)
        )

        let status = try await controller.refresh(configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.wakeBrief]))

        XCTAssertEqual(status, .running)
        XCTAssertEqual(motionCollectorFactory.collector.startCount, 1)
        XCTAssertEqual(powerCollectorFactory.collector.startCount, 1)
    }

    func testRefreshStartsMotionCollectorWhenDrivingFeatureEnabled() async throws {
        let store = ControllerTestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.drivingMode])
        )
        let motionCollectorFactory = TestMotionCollectorFactory()
        let powerCollectorFactory = TestPowerCollectorFactory()
        let controller = PassiveWakeRuntimeController(
            store: store,
            settingsStore: settingsStore,
            deliveryClient: DeliveryClient(),
            clock: FixedClock(currentDate: date(hour: 6, minute: 45)),
            motionCollectorFactory: motionCollectorFactory,
            powerCollectorFactory: powerCollectorFactory,
            motionAuthorizationProvider: StubMotionAuthorizationProvider(status: .authorized)
        )

        let status = try await controller.refresh(configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.drivingMode]))

        XCTAssertEqual(status, .running)
        XCTAssertEqual(motionCollectorFactory.collector.startCount, 1)
        XCTAssertEqual(powerCollectorFactory.collector.startCount, 1)
    }

    func testRefreshDoesNotStartCollectorWhenMotionDenied() async throws {
        let store = ControllerTestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.wakeBrief])
        )
        let motionCollectorFactory = TestMotionCollectorFactory()
        let powerCollectorFactory = TestPowerCollectorFactory()
        let controller = PassiveWakeRuntimeController(
            store: store,
            settingsStore: settingsStore,
            deliveryClient: DeliveryClient(),
            clock: FixedClock(currentDate: date(hour: 6, minute: 45)),
            motionCollectorFactory: motionCollectorFactory,
            powerCollectorFactory: powerCollectorFactory,
            motionAuthorizationProvider: StubMotionAuthorizationProvider(status: .denied)
        )

        let status = try await controller.refresh(configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.wakeBrief]))

        XCTAssertEqual(status, .permissionDenied)
        XCTAssertEqual(motionCollectorFactory.collector.startCount, 0)
        XCTAssertEqual(powerCollectorFactory.collector.startCount, 0)
    }

    func testRefreshStartsCollectorButKeepsPermissionRequiredWhenMotionNotDetermined() async throws {
        let store = ControllerTestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.wakeBrief])
        )
        let motionCollectorFactory = TestMotionCollectorFactory()
        let powerCollectorFactory = TestPowerCollectorFactory()
        let controller = PassiveWakeRuntimeController(
            store: store,
            settingsStore: settingsStore,
            deliveryClient: DeliveryClient(),
            clock: FixedClock(currentDate: date(hour: 6, minute: 45)),
            motionCollectorFactory: motionCollectorFactory,
            powerCollectorFactory: powerCollectorFactory,
            motionAuthorizationProvider: StubMotionAuthorizationProvider(status: .notDetermined)
        )

        let status = try await controller.refresh(configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.wakeBrief]))

        XCTAssertEqual(status, .permissionRequired)
        XCTAssertEqual(motionCollectorFactory.collector.startCount, 1)
        XCTAssertEqual(powerCollectorFactory.collector.startCount, 1)
    }

    func testRawMotionSignalFromCollectorEmitsMotionObservationEventWithoutChangingWakeState() async throws {
        let clock = FixedClock(currentDate: date(hour: 6, minute: 45))
        let store = ControllerTestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.wakeBrief],
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://example.com/hooks/sensekit")!,
                    bearerToken: "bearer-token",
                    hmacSecret: "hmac-secret"
                )
            )
        )
        let collectorFactory = TestMotionCollectorFactory()
        let deliveryClient = DeliveryClient(session: makeMockSession(statusCode: 200))
        let controller = PassiveWakeRuntimeController(
            store: store,
            settingsStore: settingsStore,
            deliveryClient: deliveryClient,
            clock: clock,
            motionCollectorFactory: collectorFactory,
            motionAuthorizationProvider: StubMotionAuthorizationProvider(status: .authorized)
        )

        _ = try await controller.refresh(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.wakeBrief],
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://example.com/hooks/sensekit")!,
                    bearerToken: "bearer-token",
                    hmacSecret: "hmac-secret"
                )
            )
        )

        await collectorFactory.collector.emit(
            ContextSignal(
                signalKey: MotionActivityObservation.signalKey,
                source: "test",
                weight: 1.0,
                polarity: .support,
                observedAt: clock.now(),
                validForSec: 1,
                payload: [
                    "primary_kind": .string("walking"),
                    "confidence": .string("high"),
                    "flags": .array([.string("walking")])
                ]
            )
        )

        let timelineEntries = try await store.timelineEntries(limit: 20)
        XCTAssertTrue(timelineEntries.contains { $0.message.contains("Received raw signal motion.activity_observed") })

        let state = try await store.loadRuntimeState()
        XCTAssertEqual(state.currentPlace, .other)
    }

    private func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 7, hour: hour, minute: minute))!
    }

    private func makeMockSession(statusCode: Int) -> URLSession {
        PassiveWakeMockURLProtocol.response = HTTPURLResponse(
            url: URL(string: "https://example.com/hooks/sensekit")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PassiveWakeMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

@MainActor
private final class TestMotionCollectorFactory: MotionCollectorBuilding {
    let collector = TestMotionCollector()

    func makeMotionCollector(signalHandler: @escaping SignalHandler, clock: Clock) -> any ContextSignalCollector {
        collector.signalHandler = signalHandler
        return collector
    }
}

@MainActor
private final class TestPowerCollectorFactory: PowerCollectorBuilding {
    let collector = TestPowerCollector()

    func makePowerCollector(signalHandler: @escaping SignalHandler) -> any ContextSignalCollector {
        collector.signalHandler = signalHandler
        return collector
    }
}

@MainActor
private final class TestMotionCollector: ContextSignalCollector {
    var startCount = 0
    var stopCount = 0
    var signalHandler: SignalHandler?

    func start() async {
        startCount += 1
    }

    func stop() {
        stopCount += 1
    }

    func emit(_ signal: ContextSignal) async {
        await signalHandler?(signal)
    }
}

@MainActor
private final class TestPowerCollector: ContextSignalCollector {
    var startCount = 0
    var stopCount = 0
    var signalHandler: SignalHandler?

    func start() async {
        startCount += 1
    }

    func stop() {
        stopCount += 1
    }
}

@MainActor
private final class StubMotionAuthorizationProvider: MotionAuthorizationProviding {
    private let motionStatus: MotionAuthorizationState

    init(status: MotionAuthorizationState) {
        self.motionStatus = status
    }

    func status() -> MotionAuthorizationState {
        motionStatus
    }
}

private actor ControllerTestRuntimeStore: RuntimeStore {
    private var signals: [ContextSignal] = []
    private var runtimeState = RuntimeState()
    private var debugEntries: [DebugTimelineEntry] = []
    private var auditLog: [AuditLogEntry] = []
    private var queue: [QueuedWebhook] = []

    func saveSignal(_ signal: ContextSignal) async throws {
        signals.append(signal)
    }

    func activeSignals(signalKeys: Set<String>, at date: Date) async throws -> [ContextSignal] {
        signals.filter { signalKeys.contains($0.signalKey) && $0.expiresAt >= date }
    }

    func pruneExpiredSignals(before date: Date) async throws {
        signals.removeAll { $0.expiresAt < date }
    }

    func loadRuntimeState() async throws -> RuntimeState {
        runtimeState
    }

    func saveRuntimeState(_ state: RuntimeState) async throws {
        runtimeState = state
    }

    func appendDebugEntry(_ entry: DebugTimelineEntry) async throws {
        debugEntries.append(entry)
    }

    func appendAuditEntry(_ entry: AuditLogEntry) async throws {
        auditLog.append(entry)
    }

    func enqueue(_ item: QueuedWebhook) async throws {
        queue.append(item)
    }

    func dueQueueItems(at date: Date, limit: Int) async throws -> [QueuedWebhook] {
        Array(queue.prefix(limit))
    }

    func updateQueueItem(_ item: QueuedWebhook) async throws {
        if let index = queue.firstIndex(where: { $0.id == item.id }) {
            queue[index] = item
        }
    }

    func timelineEntries(limit: Int) async throws -> [DebugTimelineEntry] {
        Array(debugEntries.prefix(limit))
    }

    func auditEntries(limit: Int) async throws -> [AuditLogEntry] {
        Array(auditLog.prefix(limit))
    }
}

private final class PassiveWakeMockURLProtocol: URLProtocol, @unchecked Sendable {
    @MainActor static var response: HTTPURLResponse?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Task {
            let response = await MainActor.run { Self.response }
                ?? HTTPURLResponse(
                    url: request.url ?? URL(string: "https://example.com")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(#"{"ok":true}"#.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
