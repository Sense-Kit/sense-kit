import Foundation
import XCTest
@testable import SenseKitRuntime

@MainActor
final class LocationRuntimeControllerTests: XCTestCase {
    func testRefreshStartsLocationCollectorForDrivingBoostWithWhenInUseAuthorization() async throws {
        let store = LocationControllerTestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.drivingMode],
                drivingLocationBoostEnabled: true
            )
        )
        let collectorFactory = TestLocationCollectorFactory()
        let authorizationProvider = StubLocationAuthorizationProvider(status: .authorizedWhenInUse)
        let controller = LocationRuntimeController(
            store: store,
            settingsStore: settingsStore,
            clock: FixedLocationClock(currentDate: date(hour: 8, minute: 15)),
            locationCollectorFactory: collectorFactory,
            locationAuthorizationProvider: authorizationProvider
        )

        let status = try await controller.refresh(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.drivingMode],
                drivingLocationBoostEnabled: true
            )
        )

        XCTAssertEqual(status, .running)
        XCTAssertEqual(collectorFactory.collector.startCount, 1)
        XCTAssertEqual(collectorFactory.collector.restoreCount, 1)
        XCTAssertTrue(authorizationProvider.requestedModes.isEmpty)
    }

    func testRefreshRequestsAlwaysAuthorizationForHomeRegionWhenOnlyWhenInUseIsGranted() async throws {
        let store = LocationControllerTestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.homeWork],
                homeRegion: .init(identifier: "home", latitude: 47.0, longitude: 8.0, radiusMeters: 150)
            )
        )
        let collectorFactory = TestLocationCollectorFactory()
        let authorizationProvider = StubLocationAuthorizationProvider(status: .authorizedWhenInUse)
        let controller = LocationRuntimeController(
            store: store,
            settingsStore: settingsStore,
            clock: FixedLocationClock(currentDate: date(hour: 8, minute: 15)),
            locationCollectorFactory: collectorFactory,
            locationAuthorizationProvider: authorizationProvider
        )

        let status = try await controller.refresh(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.homeWork],
                homeRegion: .init(identifier: "home", latitude: 47.0, longitude: 8.0, radiusMeters: 150)
            )
        )

        XCTAssertEqual(status, .permissionRequired)
        XCTAssertEqual(collectorFactory.collector.startCount, 0)
        XCTAssertEqual(authorizationProvider.requestedModes, [.always])
    }

    func testRefreshReturnsConfigurationRequiredWhenHomeWorkEnabledWithoutAnyRegions() async throws {
        let store = LocationControllerTestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.homeWork])
        )
        let collectorFactory = TestLocationCollectorFactory()
        let controller = LocationRuntimeController(
            store: store,
            settingsStore: settingsStore,
            clock: FixedLocationClock(currentDate: date(hour: 8, minute: 15)),
            locationCollectorFactory: collectorFactory,
            locationAuthorizationProvider: StubLocationAuthorizationProvider(status: .notDetermined)
        )

        let status = try await controller.refresh(
            configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.homeWork])
        )

        XCTAssertEqual(status, .configurationRequired)
        XCTAssertEqual(collectorFactory.collector.startCount, 0)
    }

    func testRefreshStartsLocationCollectorForContinuousLocationEvenWhenFixedPlacesAreNotSetYet() async throws {
        let store = LocationControllerTestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.homeWork],
                drivingLocationBoostEnabled: true
            )
        )
        let collectorFactory = TestLocationCollectorFactory()
        let authorizationProvider = StubLocationAuthorizationProvider(status: .authorizedWhenInUse)
        let controller = LocationRuntimeController(
            store: store,
            settingsStore: settingsStore,
            clock: FixedLocationClock(currentDate: date(hour: 8, minute: 15)),
            locationCollectorFactory: collectorFactory,
            locationAuthorizationProvider: authorizationProvider
        )

        let status = try await controller.refresh(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.homeWork],
                drivingLocationBoostEnabled: true
            )
        )

        XCTAssertEqual(status, .running)
        XCTAssertEqual(collectorFactory.collector.startCount, 1)
        XCTAssertEqual(collectorFactory.collector.restoreCount, 1)
    }

    func testRefreshStartsLocationCollectorForCustomFixedPlace() async throws {
        let store = LocationControllerTestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.homeWork],
                fixedPlaces: [
                    .init(
                        identifier: "place-gym",
                        displayName: "Gym",
                        latitude: 47.0,
                        longitude: 8.0,
                        radiusMeters: 150
                    )
                ]
            )
        )
        let collectorFactory = TestLocationCollectorFactory()
        let authorizationProvider = StubLocationAuthorizationProvider(status: .authorizedAlways)
        let controller = LocationRuntimeController(
            store: store,
            settingsStore: settingsStore,
            clock: FixedLocationClock(currentDate: date(hour: 8, minute: 15)),
            locationCollectorFactory: collectorFactory,
            locationAuthorizationProvider: authorizationProvider
        )

        let status = try await controller.refresh(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.homeWork],
                fixedPlaces: [
                    .init(
                        identifier: "place-gym",
                        displayName: "Gym",
                        latitude: 47.0,
                        longitude: 8.0,
                        radiusMeters: 150
                    )
                ]
            )
        )

        XCTAssertEqual(status, .running)
        XCTAssertEqual(collectorFactory.collector.startCount, 1)
        XCTAssertEqual(collectorFactory.collector.restoreCount, 1)
    }

    func testHomeRegionSignalEmitsArrivedHomeEvent() async throws {
        let clock = FixedLocationClock(currentDate: date(hour: 18, minute: 22))
        let store = LocationControllerTestRuntimeStore()
        let settingsStore = InMemorySettingsStore(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.homeWork],
                homeRegion: .init(identifier: "home", latitude: 47.0, longitude: 8.0, radiusMeters: 150),
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://example.com/hooks/sensekit")!,
                    bearerToken: "bearer-token",
                    hmacSecret: "hmac-secret"
                )
            )
        )
        let collectorFactory = TestLocationCollectorFactory()
        let deliveryClient = DeliveryClient(session: makeMockSession(statusCode: 200))
        let controller = LocationRuntimeController(
            store: store,
            settingsStore: settingsStore,
            snapshotEnricher: SnapshotEnricher(),
            policyEngine: PolicyEngine(),
            deliveryClient: deliveryClient,
            clock: clock,
            locationCollectorFactory: collectorFactory,
            locationAuthorizationProvider: StubLocationAuthorizationProvider(status: .authorizedAlways)
        )

        _ = try await controller.refresh(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.homeWork],
                homeRegion: .init(identifier: "home", latitude: 47.0, longitude: 8.0, radiusMeters: 150),
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://example.com/hooks/sensekit")!,
                    bearerToken: "bearer-token",
                    hmacSecret: "hmac-secret"
                )
            )
        )

        await collectorFactory.collector.emit(
            ContextSignal(
                signalKey: "location.region_enter_home",
                source: "test",
                weight: 0.85,
                polarity: .support,
                observedAt: clock.now(),
                validForSec: 180
            )
        )

        let timelineEntries = try await store.timelineEntries(limit: 20)
        XCTAssertTrue(timelineEntries.contains { $0.message.contains("Received signal location.region_enter_home") })
        XCTAssertTrue(timelineEntries.contains { $0.message.contains("Emitted arrived_home") })

        let auditEntries = try await store.auditEntries(limit: 20)
        XCTAssertTrue(auditEntries.contains { $0.eventType == "arrived_home" && $0.status == .delivered })
    }

    private func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 7, hour: hour, minute: minute))!
    }

    private func makeMockSession(statusCode: Int) -> URLSession {
        LocationMockURLProtocol.response = HTTPURLResponse(
            url: URL(string: "https://example.com/hooks/sensekit")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LocationMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

@MainActor
private final class TestLocationCollectorFactory: LocationCollectorBuilding {
    let collector = TestLocationCollector()

    func makeLocationCollector(configuration: RuntimeConfiguration, signalHandler: @escaping SignalHandler) -> any LocationSignalCollecting {
        collector.signalHandler = signalHandler
        return collector
    }
}

@MainActor
private final class TestLocationCollector: LocationSignalCollecting {
    var startCount = 0
    var stopCount = 0
    var restoreCount = 0
    var signalHandler: SignalHandler?

    func start() async {
        startCount += 1
    }

    func stop() {
        stopCount += 1
    }

    func restoreRegionStates() {
        restoreCount += 1
    }

    func emit(_ signal: ContextSignal) async {
        await signalHandler?(signal)
    }
}

@MainActor
private final class StubLocationAuthorizationProvider: LocationAuthorizationProviding {
    private let locationStatus: LocationAuthorizationState
    private(set) var requestedModes: [LocationAuthorizationMode] = []

    init(status: LocationAuthorizationState) {
        self.locationStatus = status
    }

    func status() -> LocationAuthorizationState {
        locationStatus
    }

    func requestAuthorization(mode: LocationAuthorizationMode) {
        requestedModes.append(mode)
    }
}

private final class FixedLocationClock: @unchecked Sendable, Clock {
    let currentDate: Date

    init(currentDate: Date) {
        self.currentDate = currentDate
    }

    func now() -> Date {
        currentDate
    }
}

private actor LocationControllerTestRuntimeStore: RuntimeStore {
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

private final class LocationMockURLProtocol: URLProtocol, @unchecked Sendable {
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
