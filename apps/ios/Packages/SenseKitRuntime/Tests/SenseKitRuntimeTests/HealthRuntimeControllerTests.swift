import Foundation
import XCTest
@testable import SenseKitRuntime

@MainActor
final class HealthRuntimeControllerTests: XCTestCase {
    func testRefreshStartsHealthCollectorWhenWorkoutFeatureEnabled() async throws {
        let store = HealthControllerTestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.workoutFollowUp])
        )
        let collectorFactory = TestHealthCollectorFactory()
        let controller = HealthRuntimeController(
            store: store,
            settingsStore: settingsStore,
            clock: FixedHealthClock(currentDate: date(hour: 9, minute: 15)),
            healthCollectorFactory: collectorFactory,
            healthAuthorizationProvider: StubHealthAuthorizationProvider(status: .authorized)
        )

        let status = try await controller.refresh(
            configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.workoutFollowUp])
        )

        XCTAssertEqual(status, .running)
        XCTAssertEqual(collectorFactory.collector.startCount, 1)
    }

    func testRefreshRequestsAuthorizationWhenWorkoutFeatureEnabledButPermissionUndetermined() async throws {
        let store = HealthControllerTestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.workoutFollowUp])
        )
        let collectorFactory = TestHealthCollectorFactory()
        let authorizationProvider = StubHealthAuthorizationProvider(status: .notDetermined)
        let controller = HealthRuntimeController(
            store: store,
            settingsStore: settingsStore,
            clock: FixedHealthClock(currentDate: date(hour: 9, minute: 15)),
            healthCollectorFactory: collectorFactory,
            healthAuthorizationProvider: authorizationProvider
        )

        let status = try await controller.refresh(
            configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.workoutFollowUp])
        )

        XCTAssertEqual(status, .permissionRequired)
        XCTAssertEqual(collectorFactory.collector.startCount, 0)
        XCTAssertEqual(authorizationProvider.requestAuthorizationCount, 1)
    }

    func testRefreshStopsWhenWorkoutFeatureDisabled() async throws {
        let store = HealthControllerTestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(deviceID: "device-1")
        )
        let collectorFactory = TestHealthCollectorFactory()
        let controller = HealthRuntimeController(
            store: store,
            settingsStore: settingsStore,
            clock: FixedHealthClock(currentDate: date(hour: 9, minute: 15)),
            healthCollectorFactory: collectorFactory,
            healthAuthorizationProvider: StubHealthAuthorizationProvider(status: .authorized)
        )

        let status = try await controller.refresh(
            configuration: RuntimeConfiguration(deviceID: "device-1")
        )

        XCTAssertEqual(status, .inactive)
        XCTAssertEqual(collectorFactory.collector.startCount, 0)
    }

    private func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 8, hour: hour, minute: minute))!
    }
}

@MainActor
private final class TestHealthCollectorFactory: HealthCollectorBuilding {
    let collector = TestHealthCollector()

    func makeHealthCollector(signalHandler: @escaping SignalHandler) -> any ContextSignalCollector {
        collector.signalHandler = signalHandler
        return collector
    }
}

@MainActor
private final class TestHealthCollector: ContextSignalCollector {
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
private final class StubHealthAuthorizationProvider: HealthAuthorizationProviding {
    private let healthStatus: HealthAuthorizationState
    private(set) var requestAuthorizationCount = 0

    init(status: HealthAuthorizationState) {
        self.healthStatus = status
    }

    func status() -> HealthAuthorizationState {
        healthStatus
    }

    func requestAuthorization() async {
        requestAuthorizationCount += 1
    }
}

private final class FixedHealthClock: @unchecked Sendable, Clock {
    let currentDate: Date

    init(currentDate: Date) {
        self.currentDate = currentDate
    }

    func now() -> Date {
        currentDate
    }
}

private actor HealthControllerTestRuntimeStore: RuntimeStore {
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
