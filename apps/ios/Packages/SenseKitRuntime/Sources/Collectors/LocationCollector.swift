import Foundation

#if os(iOS) && canImport(CoreLocation)
import CoreLocation

@MainActor
public final class LocationCollector: NSObject, LocationSignalCollecting {
    private let manager = CLLocationManager()
    private let signalHandler: SignalHandler
    private let configuration: RuntimeConfiguration

    public init(configuration: RuntimeConfiguration, signalHandler: @escaping SignalHandler) {
        self.configuration = configuration
        self.signalHandler = signalHandler
        super.init()
        manager.delegate = self
    }

    public func start() async {
        manager.allowsBackgroundLocationUpdates = true
        manager.startMonitoringSignificantLocationChanges()

        for region in configuration.monitoredRegions {
            manager.startMonitoring(for: makeRegion(from: region))
        }
    }

    public func stop() {
        manager.stopMonitoringSignificantLocationChanges()
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
    }

    public func restoreRegionStates() {
        for region in manager.monitoredRegions {
            manager.requestState(for: region)
        }
    }
}

@MainActor
extension LocationCollector: @preconcurrency CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        emitRegionSignal(kind: "enter", region: region)
    }

    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        emitRegionSignal(kind: "exit", region: region)
    }

    public func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        switch state {
        case .inside:
            locationManager(manager, didEnterRegion: region)
        case .outside:
            locationManager(manager, didExitRegion: region)
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let observedAt = Date()
        let speedMetersPerSecond = max(location.speed, 0)
        let speedKilometersPerHour = speedMetersPerSecond * 3.6

        Task {
            await signalHandler(
                ContextSignal(
                    signalKey: "location.location_observed",
                    collector: .location,
                    source: "corelocation_significant_change",
                    weight: 1.0,
                    polarity: .support,
                    observedAt: observedAt,
                    receivedAt: observedAt,
                    validForSec: 300,
                    payload: locationPayload(from: location, speedKilometersPerHour: speedKilometersPerHour)
                )
            )
        }
    }

    private func makeRegion(from configuration: RegionConfiguration) -> CLCircularRegion {
        let center = CLLocationCoordinate2D(latitude: configuration.latitude, longitude: configuration.longitude)
        let region = CLCircularRegion(center: center, radius: configuration.radiusMeters, identifier: configuration.identifier)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }

    private func emitRegionSignal(kind: String, region: CLRegion) {
        guard let place = configuration.region(for: region.identifier) else {
            return
        }

        let observedAt = Date()

        Task {
            await signalHandler(
                ContextSignal(
                    signalKey: "location.region_state_changed",
                    collector: .location,
                    source: "corelocation_region",
                    weight: 1.0,
                    polarity: .support,
                    observedAt: observedAt,
                    receivedAt: observedAt,
                    validForSec: 180,
                    payload: placePayload(from: place, transition: kind)
                )
            )
        }
    }

    private func locationPayload(from location: CLLocation, speedKilometersPerHour: Double) -> [String: JSONValue] {
        var payload: [String: JSONValue] = [
            "horizontal_accuracy_m": .number(location.horizontalAccuracy),
            "vertical_accuracy_m": .number(location.verticalAccuracy),
            "speed_mps": .number(max(location.speed, 0)),
            "speed_kmh": .number(speedKilometersPerHour),
            "course_deg": .number(location.course),
            "altitude_m": .number(location.altitude),
            "timestamp": .string(ISO8601DateFormatter().string(from: location.timestamp))
        ]

        if configuration.placeSharingMode == .preciseCoordinates {
            payload["latitude"] = .number(location.coordinate.latitude)
            payload["longitude"] = .number(location.coordinate.longitude)
        }

        return payload
    }

    private func placePayload(from region: RegionConfiguration, transition: String) -> [String: JSONValue] {
        var payload: [String: JSONValue] = [
            "transition": .string(transition),
            "place_identifier": .string(region.identifier),
            "place_type": .string(placeType(for: region.identifier).rawValue),
            "radius_m": .number(region.radiusMeters)
        ]

        if let displayName = region.displayName, !displayName.isEmpty {
            payload["place_name"] = .string(displayName)
        }

        if configuration.placeSharingMode == .preciseCoordinates {
            payload["latitude"] = .number(region.latitude)
            payload["longitude"] = .number(region.longitude)
        }

        return payload
    }

    private func placeType(for identifier: String) -> PlaceType {
        if identifier == configuration.homeRegion?.identifier {
            return .home
        }

        if identifier == configuration.workRegion?.identifier {
            return .work
        }

        return .custom
    }
}
#else
public final class LocationCollector: LocationSignalCollecting {
    public init(configuration: RuntimeConfiguration, signalHandler: @escaping SignalHandler) {}
    public func start() async {}
    public func stop() {}
    public func restoreRegionStates() {}
}
#endif
