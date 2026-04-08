import Foundation
import XCTest
@testable import SenseKitRuntime

final class BackgroundWakeCoordinatorTests: XCTestCase {
    func testSendTestScenarioDeliversDrivingSignalsAsRawSignalBatch() async throws {
        let clock = FixedClock(currentDate: date(hour: 12, minute: 15))
        let store = TestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(
                deviceID: "test-device",
                placeSharingMode: .preciseCoordinates,
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

        let coordinator = makeCoordinator(clock: clock, store: store, settingsStore: settingsStore, statusCode: 200)

        let result = try await coordinator.sendTestScenario(.drivingSignals)

        XCTAssertEqual(result.deliveryLabel, "manual.driving_signals")
        XCTAssertEqual(result.signalBatch.signals.count, 2)
        XCTAssertEqual(result.signalBatch.signals[0].signalKey, "motion.activity_observed")
        XCTAssertEqual(result.signalBatch.signals[1].signalKey, "location.location_observed")

        let auditEntries = try await store.auditEntries(limit: 10)
        XCTAssertEqual(auditEntries.count, 2)
        XCTAssertEqual(auditEntries[0].status, .queued)
        XCTAssertEqual(auditEntries[1].status, .delivered)
        XCTAssertEqual(auditEntries[1].eventType, "manual.driving_signals")

        let request = await MockURLProtocol.lastRequest()
        let deliveredBody = try XCTUnwrap(requestBody(from: try XCTUnwrap(request)))
        let deliveredBatch = try JSONCoding.decoder.decode(SenseKitSignalBatch.self, from: deliveredBody)
        XCTAssertEqual(deliveredBatch.schemaVersion, "sensekit.signal_batch.v1")
        XCTAssertEqual(deliveredBatch.device.deviceID, "test-device")
        XCTAssertEqual(deliveredBatch.device.placeSharingMode, .preciseCoordinates)
        XCTAssertEqual(deliveredBatch.signals.count, 2)
        XCTAssertEqual(deliveredBatch.signals[0].collector, .manual)
        XCTAssertEqual(deliveredBatch.signals[1].collector, .manual)
        XCTAssertNotNil(deliveredBatch.signals[1].payload["latitude"])
        XCTAssertNotNil(deliveredBatch.signals[1].payload["longitude"])
    }

    func testHandleWakeDeliversSingleRawSignalBatchAndUpdatesPlaceState() async throws {
        let clock = FixedClock(currentDate: date(hour: 18, minute: 20))
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

        let coordinator = makeCoordinator(clock: clock, store: store, settingsStore: settingsStore, statusCode: 200)
        let results = try await coordinator.handleWake(
            signal: ContextSignal(
                signalKey: "location.region_state_changed",
                source: "corelocation_region",
                weight: 1.0,
                polarity: .support,
                observedAt: clock.now(),
                validForSec: 180,
                payload: [
                    "transition": .string("enter"),
                    "place_identifier": .string("place-gym"),
                    "place_name": .string("Gym"),
                    "place_type": .string("custom"),
                    "radius_m": .number(150)
                ]
            )
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].deliveryLabel, "location.region_state_changed")
        XCTAssertEqual(results[0].signalBatch.signals.count, 1)
        XCTAssertEqual(results[0].signalBatch.signals[0].collector, .location)

        let state = try await store.loadRuntimeState()
        XCTAssertEqual(state.currentPlace, .custom)
        XCTAssertEqual(state.currentPlaceIdentifier, "place-gym")
        XCTAssertEqual(state.currentPlaceName, "Gym")

        let timelineEntries = try await store.timelineEntries(limit: 20)
        XCTAssertTrue(timelineEntries.contains { $0.message.contains("Received raw signal location.region_state_changed") })

        let request = await MockURLProtocol.lastRequest()
        let deliveredBody = try XCTUnwrap(requestBody(from: try XCTUnwrap(request)))
        let deliveredBatch = try JSONCoding.decoder.decode(SenseKitSignalBatch.self, from: deliveredBody)
        XCTAssertEqual(deliveredBatch.signals.count, 1)
        XCTAssertEqual(deliveredBatch.signals[0].signalKey, "location.region_state_changed")
    }

    func testSendTestScenarioOmitsCoordinatesWhenPlaceSharingIsLabelsOnly() async throws {
        let clock = FixedClock(currentDate: date(hour: 18, minute: 15))
        let store = TestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(
                deviceID: "test-device",
                placeSharingMode: .labelsOnly,
                fixedPlaces: [
                    .init(
                        identifier: "place-gym",
                        displayName: "Gym",
                        latitude: 47.3769,
                        longitude: 8.5417,
                        radiusMeters: 150
                    )
                ],
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

        let coordinator = makeCoordinator(clock: clock, store: store, settingsStore: settingsStore, statusCode: 200)
        _ = try await coordinator.sendTestScenario(.placeArrival)

        let request = await MockURLProtocol.lastRequest()
        let deliveredBody = try XCTUnwrap(requestBody(from: try XCTUnwrap(request)))
        let deliveredBatch = try JSONCoding.decoder.decode(SenseKitSignalBatch.self, from: deliveredBody)
        let payload = deliveredBatch.signals[0].payload
        XCTAssertNil(payload["latitude"])
        XCTAssertNil(payload["longitude"])
    }

    func testSendTestScenarioIncludesCoordinatesWhenPlaceSharingIsPrecise() async throws {
        let clock = FixedClock(currentDate: date(hour: 18, minute: 16))
        let store = TestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(
                deviceID: "test-device",
                placeSharingMode: .preciseCoordinates,
                fixedPlaces: [
                    .init(
                        identifier: "place-gym",
                        displayName: "Gym",
                        latitude: 47.3769,
                        longitude: 8.5417,
                        radiusMeters: 150
                    )
                ],
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

        let coordinator = makeCoordinator(clock: clock, store: store, settingsStore: settingsStore, statusCode: 200)
        _ = try await coordinator.sendTestScenario(.placeArrival)

        let request = await MockURLProtocol.lastRequest()
        let deliveredBody = try XCTUnwrap(requestBody(from: try XCTUnwrap(request)))
        let deliveredBatch = try JSONCoding.decoder.decode(SenseKitSignalBatch.self, from: deliveredBody)
        let payload = deliveredBatch.signals[0].payload
        XCTAssertEqual(payload["latitude"], .number(47.3769))
        XCTAssertEqual(payload["longitude"], .number(8.5417))
    }

    func testSendTestScenarioMarksNon2xxResponsesAsFailedAndRetryable() async throws {
        let clock = FixedClock(currentDate: date(hour: 12, minute: 22))
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
                statusCode: 502,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"ok":false,"error":"bad gateway"}"#.utf8))
        }

        let coordinator = makeCoordinator(clock: clock, store: store, settingsStore: settingsStore, statusCode: 502)

        _ = try await coordinator.sendTestScenario(.placeArrival)

        let auditEntries = try await store.auditEntries(limit: 10)
        XCTAssertEqual(auditEntries.count, 2)
        XCTAssertEqual(auditEntries[0].status, .queued)
        XCTAssertEqual(auditEntries[1].status, .failed)
        XCTAssertTrue(auditEntries[1].payloadSummary.contains("HTTP 502"))

        let queuedItems = await store.queuedItems()
        XCTAssertEqual(queuedItems.count, 1)
        XCTAssertEqual(queuedItems[0].status, .retryWait)
        XCTAssertEqual(queuedItems[0].attempt, 2)
        XCTAssertNotNil(queuedItems[0].retryAt)
    }

    private func makeCoordinator(
        clock: FixedClock,
        store: TestRuntimeStore,
        settingsStore: InMemorySettingsStore,
        statusCode: Int
    ) -> BackgroundWakeCoordinator {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfiguration)

        return BackgroundWakeCoordinator(
            store: store,
            deliveryClient: DeliveryClient(session: session),
            settingsStore: settingsStore,
            clock: clock
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 7, hour: hour, minute: minute))!
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

    func queuedItems() -> [QueuedWebhook] {
        queue
    }
}
