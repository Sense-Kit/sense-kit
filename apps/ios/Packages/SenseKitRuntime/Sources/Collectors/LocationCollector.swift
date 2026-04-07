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
        manager.startMonitoringSignificantLocationChanges()

        if let home = configuration.homeRegion {
            manager.startMonitoring(for: makeRegion(from: home))
        }

        if let work = configuration.workRegion {
            manager.startMonitoring(for: makeRegion(from: work))
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
        Task {
            let key = region.identifier == configuration.homeRegion?.identifier ? "location.region_enter_home" : "location.region_enter_work"
            await signalHandler(
                ContextSignal(
                    signalKey: key,
                    source: "corelocation_region",
                    weight: 0.85,
                    polarity: .support,
                    observedAt: Date(),
                    validForSec: 180
                )
            )
            await signalHandler(
                ContextSignal(
                    signalKey: "place.arrived_home_or_work",
                    source: "corelocation_region",
                    weight: 0.10,
                    polarity: .support,
                    observedAt: Date(),
                    validForSec: 180
                )
            )
        }
    }

    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task {
            let key = region.identifier == configuration.homeRegion?.identifier ? "location.region_exit_home" : "location.region_exit_work"
            await signalHandler(
                ContextSignal(
                    signalKey: key,
                    source: "corelocation_region",
                    weight: 0.85,
                    polarity: .support,
                    observedAt: Date(),
                    validForSec: 180
                )
            )
        }
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
        let speedMetersPerSecond = max(location.speed, 0)
        let speedKilometersPerHour = speedMetersPerSecond * 3.6

        Task {
            if configuration.drivingLocationBoostEnabled, speedKilometersPerHour >= 18 {
                await signalHandler(
                    ContextSignal(
                        signalKey: "location.speed_above_18_kmh",
                        source: "corelocation_significant_change",
                        weight: 0.10,
                        polarity: .support,
                        observedAt: Date(),
                        validForSec: 120,
                        payload: ["speed_kmh": .number(speedKilometersPerHour)]
                    )
                )
                await signalHandler(
                    ContextSignal(
                        signalKey: "location.significant_change_while_automotive",
                        source: "corelocation_significant_change",
                        weight: 0.10,
                        polarity: .support,
                        observedAt: Date(),
                        validForSec: 300,
                        payload: ["speed_kmh": .number(speedKilometersPerHour)]
                    )
                )
            }

            if speedKilometersPerHour < 5 {
                await signalHandler(
                    ContextSignal(
                        signalKey: "location.speed_below_5_kmh_sustained_120s",
                        source: "corelocation_significant_change",
                        weight: 0.10,
                        polarity: .support,
                        observedAt: Date(),
                        validForSec: 120
                    )
                )
            }

            if speedKilometersPerHour < 8 {
                await signalHandler(
                    ContextSignal(
                        signalKey: "location.speed_below_8_kmh",
                        source: "corelocation_significant_change",
                        weight: 0.05,
                        polarity: .support,
                        observedAt: Date(),
                        validForSec: 90
                    )
                )
            } else if speedKilometersPerHour > 40 {
                await signalHandler(
                    ContextSignal(
                        signalKey: "location.speed_high",
                        source: "corelocation_significant_change",
                        weight: 0.20,
                        polarity: .oppose,
                        observedAt: Date(),
                        validForSec: 90
                    )
                )
            }
        }
    }

    private func makeRegion(from configuration: RegionConfiguration) -> CLCircularRegion {
        let center = CLLocationCoordinate2D(latitude: configuration.latitude, longitude: configuration.longitude)
        let region = CLCircularRegion(center: center, radius: configuration.radiusMeters, identifier: configuration.identifier)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
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
