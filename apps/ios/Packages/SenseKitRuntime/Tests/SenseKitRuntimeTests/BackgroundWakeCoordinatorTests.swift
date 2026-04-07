import Foundation
import XCTest
@testable import SenseKitRuntime

final class BackgroundWakeCoordinatorTests: XCTestCase {
    func testSendTestEventDeliversAndWritesAuditAndTimeline() async throws {
        let clock = FixedClock(currentDate: date(hour: 12, minute: 15))
        let store = TestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(
                deviceID: "test-device",
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://example.com/hooks/sensekit")!,
                    bearerToken: "bearer-token",
                    hmacSecret: "hmac-secret"
                )
            )
        )

        await MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.com/hooks/sensekit")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer bearer-token")
            XCTAssertEqual(request.httpMethod, "POST")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"ok":true}"#.utf8))
        }

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfiguration)
        let healthSnapshot = makeHealthSnapshot(capturedAt: clock.now())

        let coordinator = BackgroundWakeCoordinator(
            store: store,
            engine: CorroborationEngine(
                store: store,
                configuration: RuntimeConfiguration(deviceID: "test-device"),
                clock: clock
            ),
            snapshotEnricher: SnapshotEnricher(
                provider: DefaultSnapshotProvider(),
                healthProvider: StubHealthSnapshotProvider(health: healthSnapshot)
            ),
            policyEngine: PolicyEngine(),
            deliveryClient: DeliveryClient(session: session),
            settingsStore: settingsStore,
            clock: clock
        )

        let result = try await coordinator.sendTestEvent(.drivingStarted)

        XCTAssertEqual(result.event.eventType, .drivingStarted)
        XCTAssertEqual(result.event.confidence, 1.0)
        XCTAssertEqual(result.event.reasons, ["manual.test_button"])

        let auditEntries = try await store.auditEntries(limit: 10)
        XCTAssertEqual(auditEntries.count, 2)
        XCTAssertEqual(auditEntries[0].status, .queued)
        XCTAssertEqual(auditEntries[1].status, .delivered)
        XCTAssertEqual(auditEntries[1].destination, "https://example.com/hooks/sensekit")

        let timelineEntries = try await store.timelineEntries(limit: 10)
        XCTAssertTrue(timelineEntries.contains { $0.message.contains("Manual test event driving_started") })

        let state = try await store.loadRuntimeState()
        XCTAssertTrue(state.isDriving)

        let request = await MockURLProtocol.lastRequest()
        let deliveredRequest = try XCTUnwrap(request)
        let deliveredBody = try XCTUnwrap(requestBody(from: deliveredRequest))
        let deliveredEnvelope = try JSONCoding.decoder.decode(SenseKitEventEnvelope.self, from: deliveredBody)
        XCTAssertEqual(deliveredEnvelope.snapshot.health, healthSnapshot)
        XCTAssertEqual(deliveredEnvelope.snapshot.health.nutrition.proteinRemainingG, 42)
    }

    func testHandleWakeForRawMotionSignalDeliversDirectMotionEvent() async throws {
        let clock = FixedClock(currentDate: date(hour: 12, minute: 18))
        let store = TestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(
                deviceID: "test-device",
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://example.com/hooks/sensekit")!,
                    bearerToken: "bearer-token",
                    hmacSecret: "hmac-secret"
                )
            )
        )

        await MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.com/hooks/sensekit")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer bearer-token")
            XCTAssertEqual(request.httpMethod, "POST")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"ok":true}"#.utf8))
        }

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfiguration)

        let coordinator = BackgroundWakeCoordinator(
            store: store,
            engine: CorroborationEngine(
                store: store,
                configuration: RuntimeConfiguration(deviceID: "test-device"),
                clock: clock
            ),
            snapshotEnricher: SnapshotEnricher(),
            policyEngine: PolicyEngine(),
            deliveryClient: DeliveryClient(session: session),
            settingsStore: settingsStore,
            clock: clock
        )

        let results = try await coordinator.handleWake(
            signal: ContextSignal(
                signalKey: MotionActivityObservation.signalKey,
                source: "coremotion_activity",
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

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].event.eventType, .motionActivityObserved)
        XCTAssertEqual(results[0].event.confidence, 1.0)
        XCTAssertEqual(results[0].event.reasons, ["motion.primary.walking", "motion.confidence.high", "motion.flag.walking"])

        let timelineEntries = try await store.timelineEntries(limit: 10)
        XCTAssertTrue(timelineEntries.contains { $0.message.contains("Received raw motion activity walking") })
        XCTAssertFalse(timelineEntries.contains { $0.message.contains("Emitted motion_activity_observed") })

        let state = try await store.loadRuntimeState()
        XCTAssertNil(state.lastWakeAt)
        XCTAssertFalse(state.isDriving)
    }

    func testHandleWakeForHealthSnapshotChangedSignalDeliversNeutralHealthEvent() async throws {
        let clock = FixedClock(currentDate: date(hour: 12, minute: 25))
        let store = TestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(
                deviceID: "test-device",
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://example.com/hooks/sensekit")!,
                    bearerToken: "bearer-token",
                    hmacSecret: "hmac-secret"
                )
            )
        )

        await MockURLProtocol.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"ok":true}"#.utf8))
        }

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfiguration)
        let healthSnapshot = makeHealthSnapshot(capturedAt: clock.now())

        let coordinator = BackgroundWakeCoordinator(
            store: store,
            engine: CorroborationEngine(
                store: store,
                configuration: RuntimeConfiguration(deviceID: "test-device"),
                clock: clock
            ),
            snapshotEnricher: SnapshotEnricher(
                provider: DefaultSnapshotProvider(),
                healthProvider: StubHealthSnapshotProvider(health: healthSnapshot)
            ),
            policyEngine: PolicyEngine(),
            deliveryClient: DeliveryClient(session: session),
            settingsStore: settingsStore,
            clock: clock
        )

        let results = try await coordinator.handleWake(
            signal: ContextSignal(
                signalKey: "health.snapshot_changed",
                source: "healthkit_observer",
                weight: 1.0,
                polarity: .support,
                observedAt: clock.now(),
                validForSec: 60,
                payload: [
                    "domains": .array([.string("sleep"), .string("nutrition")])
                ]
            )
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].event.eventType, .healthSnapshotUpdated)
        XCTAssertEqual(results[0].event.reasons, ["health_domain.sleep", "health_domain.nutrition"])

        let request = await MockURLProtocol.lastRequest()
        let deliveredRequest = try XCTUnwrap(request)
        let deliveredBody = try XCTUnwrap(requestBody(from: deliveredRequest))
        let deliveredEnvelope = try JSONCoding.decoder.decode(SenseKitEventEnvelope.self, from: deliveredBody)
        XCTAssertEqual(deliveredEnvelope.event.eventType, .healthSnapshotUpdated)
        XCTAssertEqual(deliveredEnvelope.snapshot.health, healthSnapshot)
        XCTAssertEqual(deliveredEnvelope.policy.allowedActions, ["update_context"])
    }

    private func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 7, hour: hour, minute: minute))!
    }

    private func makeHealthSnapshot(capturedAt: Date) -> HealthSnapshot {
        HealthSnapshot(
            capturedAt: capturedAt,
            sleep: .init(
                available: true,
                authorized: true,
                freshness: .recent,
                lastSleepStartAt: date(hour: 22, minute: 40),
                lastSleepEndAt: date(hour: 6, minute: 30),
                asleepMinutes: 470,
                inBedMinutes: 495,
                sevenDayAvgAsleepMinutes: 455,
                deltaVsSevenDayAvgMinutes: 15
            ),
            workout: .init(
                available: true,
                authorized: true,
                freshness: .recent,
                active: false,
                todayCount: 1,
                todayTotalMinutes: 48,
                todayActiveEnergyKcal: 320,
                lastType: "traditional_strength_training",
                lastStartAt: date(hour: 9, minute: 15),
                lastEndAt: date(hour: 10, minute: 3)
            ),
            nutrition: .init(
                available: true,
                authorized: true,
                freshness: .recent,
                lastLoggedAt: date(hour: 12, minute: 10),
                proteinG: 118,
                proteinTargetG: 160,
                proteinRemainingG: 42,
                caloriesKcal: 2_110,
                caloriesTargetKcal: 2_700,
                caloriesRemainingKcal: 590,
                waterML: 1_650,
                waterTargetML: 3_000,
                waterRemainingML: 1_350
            ),
            activity: .init(
                available: true,
                authorized: true,
                freshness: .recent,
                steps: 7_420,
                activeEnergyKcal: 612,
                distanceKM: 5.8,
                sevenDayAvgStepsByNow: 9_100,
                deltaVsSevenDayAvgStepsByNow: -1_680
            ),
            recovery: .init(
                available: true,
                authorized: true,
                freshness: .recent,
                restingHeartRateBPM: 54,
                restingHeartRateDeltaVs14DayAvgBPM: 4,
                hrvSDNNMs: 39,
                hrvDeltaVs14DayAvgMs: -11,
                measuredAt: date(hour: 5, minute: 40)
            ),
            mind: .init(
                available: true,
                authorized: false,
                freshness: .stale,
                latestState: nil,
                loggedAt: nil
            )
        )
    }

    private func requestBody(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 1_024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var data = Data()
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read < 0 {
                return nil
            }
            if read == 0 {
                break
            }
            data.append(buffer, count: read)
        }
        return data
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    private actor RequestHandlerStore {
        private var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
        private var lastRequest: URLRequest?

        func set(_ handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?) {
            requestHandler = handler
            lastRequest = nil
        }

        func load() -> (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))? {
            requestHandler
        }

        func saveLastRequest(_ request: URLRequest) {
            lastRequest = request
        }

        func loadLastRequest() -> URLRequest? {
            lastRequest
        }
    }

    private static let requestHandlerStore = RequestHandlerStore()

    static func setRequestHandler(_ handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?) async {
        await requestHandlerStore.set(handler)
    }

    static func lastRequest() async -> URLRequest? {
        await requestHandlerStore.loadLastRequest()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Task {
            await Self.requestHandlerStore.saveLastRequest(request)
            guard let handler = await Self.requestHandlerStore.load() else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }

            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
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
        Array(queue.filter { $0.status == .queued || $0.status == .retryWait }.prefix(limit))
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

private struct StubHealthSnapshotProvider: HealthSnapshotProviding {
    let health: HealthSnapshot

    func currentHealthSnapshot(at date: Date, state: RuntimeState) async -> HealthSnapshot {
        health
    }
}
