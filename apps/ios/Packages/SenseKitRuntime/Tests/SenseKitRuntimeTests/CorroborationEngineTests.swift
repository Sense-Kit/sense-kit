import Foundation
import XCTest
@testable import SenseKitRuntime

final class CorroborationEngineTests: XCTestCase {
    func testWakeConfirmedFiresInsideWakeWindow() async throws {
        let clock = TestClock(date: date(hour: 6, minute: 45))
        let configuration = RuntimeConfiguration(deviceID: "test-device", wakeWindowStartHour: 4, wakeWindowEndHour: 11)
        let store = TestRuntimeStore()
        let engine = CorroborationEngine(store: store, configuration: configuration, clock: clock)

        _ = try await engine.ingest(signal(key: "motion.stationary_to_walking_after_rest", weight: 0.35, at: clock.now()))
        let evaluations = try await engine.ingest(signal(key: "motion.walking_sustained_60s", weight: 0.20, at: clock.now()))

        XCTAssertEqual(evaluations.count, 1)
        XCTAssertEqual(evaluations.first?.event.eventType, .wakeConfirmed)
    }

    func testWakeConfirmedDoesNotFireOutsideWakeWindowWithoutBoost() async throws {
        let clock = TestClock(date: date(hour: 1, minute: 15))
        let configuration = RuntimeConfiguration(deviceID: "test-device", wakeWindowStartHour: 4, wakeWindowEndHour: 11)
        let store = TestRuntimeStore()
        let engine = CorroborationEngine(store: store, configuration: configuration, clock: clock)

        _ = try await engine.ingest(signal(key: "motion.stationary_to_walking_after_rest", weight: 0.35, at: clock.now()))
        let evaluations = try await engine.ingest(signal(key: "motion.walking_sustained_60s", weight: 0.20, at: clock.now()))

        XCTAssertTrue(evaluations.isEmpty)
    }

    func testDrivingStartedFiresFromMotionOnlyPath() async throws {
        let clock = TestClock(date: date(hour: 8, minute: 10))
        let configuration = RuntimeConfiguration(deviceID: "test-device")
        let store = TestRuntimeStore()
        let engine = CorroborationEngine(store: store, configuration: configuration, clock: clock)

        _ = try await engine.ingest(signal(key: "motion.automotive_entered", weight: 0.45, at: clock.now()))
        let evaluations = try await engine.ingest(signal(key: "motion.automotive_sustained_180s", weight: 0.20, at: clock.now()))

        XCTAssertEqual(evaluations.count, 1)
        XCTAssertEqual(evaluations.first?.event.eventType, .drivingStarted)
    }

    func testArrivedHomeFiresOnRegionEntryAlone() async throws {
        let clock = TestClock(date: date(hour: 17, minute: 22))
        let configuration = RuntimeConfiguration(deviceID: "test-device")
        let store = TestRuntimeStore()
        let engine = CorroborationEngine(store: store, configuration: configuration, clock: clock)

        let evaluations = try await engine.ingest(signal(key: "location.region_enter_home", weight: 0.85, at: clock.now()))

        XCTAssertEqual(evaluations.count, 1)
        XCTAssertEqual(evaluations.first?.event.eventType, .arrivedHome)
    }

    func testCooldownBlocksImmediateDuplicateDrivingStarted() async throws {
        let clock = TestClock(date: date(hour: 8, minute: 10))
        let configuration = RuntimeConfiguration(deviceID: "test-device")
        let store = TestRuntimeStore()
        let engine = CorroborationEngine(store: store, configuration: configuration, clock: clock)

        _ = try await engine.ingest(signal(key: "motion.automotive_entered", weight: 0.45, at: clock.now()))
        _ = try await engine.ingest(signal(key: "motion.automotive_sustained_180s", weight: 0.20, at: clock.now()))
        let secondAttempt = try await engine.ingest(signal(key: "motion.automotive_entered", weight: 0.45, at: clock.now()))

        XCTAssertTrue(secondAttempt.isEmpty)
    }

    private func signal(key: String, weight: Double, at date: Date, polarity: SignalPolarity = .support) -> ContextSignal {
        ContextSignal(
            signalKey: key,
            source: "test",
            weight: weight,
            polarity: polarity,
            observedAt: date,
            validForSec: 300
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: hour, minute: minute))!
    }
}

private final class TestClock: @unchecked Sendable, Clock {
    var currentDate: Date

    init(date: Date) {
        self.currentDate = date
    }

    func now() -> Date {
        currentDate
    }
}

private actor TestRuntimeStore: RuntimeStore {
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
