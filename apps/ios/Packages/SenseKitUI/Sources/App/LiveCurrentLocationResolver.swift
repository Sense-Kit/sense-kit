import Foundation
import SenseKitRuntime

#if os(iOS) && canImport(CoreLocation)
import CoreLocation

@MainActor
final class LiveCurrentLocationResolver: NSObject, @unchecked Sendable {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<RegionConfiguration, Error>?
    private var pendingIdentifier = "home"
    private var pendingRadiusMeters = 150.0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func captureCurrentRegion(identifier: String, radiusMeters: Double) async throws -> RegionConfiguration {
        guard CLLocationManager.locationServicesEnabled() else {
            throw CurrentLocationResolverError.unavailable
        }

        if continuation != nil {
            throw CurrentLocationResolverError.busy
        }

        pendingIdentifier = identifier
        pendingRadiusMeters = radiusMeters

        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            throw CurrentLocationResolverError.permissionDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                resume(with: .failure(CurrentLocationResolverError.permissionDenied))
            @unknown default:
                resume(with: .failure(CurrentLocationResolverError.unavailable))
            }
        }
    }

    private func resume(with result: Result<RegionConfiguration, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}

extension LiveCurrentLocationResolver: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if continuation != nil {
                manager.requestLocation()
            }
        case .denied, .restricted:
            resume(with: .failure(CurrentLocationResolverError.permissionDenied))
        case .notDetermined:
            break
        @unknown default:
            resume(with: .failure(CurrentLocationResolverError.unavailable))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            resume(with: .failure(CurrentLocationResolverError.noLocation))
            return
        }

        resume(
            with: .success(
                RegionConfiguration(
                    identifier: pendingIdentifier,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    radiusMeters: pendingRadiusMeters
                )
            )
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resume(with: .failure(error))
    }
}

private enum CurrentLocationResolverError: LocalizedError {
    case unavailable
    case permissionDenied
    case noLocation
    case busy

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Location services are unavailable on this device."
        case .permissionDenied:
            return "Location permission is denied. Turn it back on in iPhone Settings."
        case .noLocation:
            return "iPhone could not determine the current location yet."
        case .busy:
            return "SenseKit is already waiting for a location fix."
        }
    }
}
#else
final class LiveCurrentLocationResolver: @unchecked Sendable {
    func captureCurrentRegion(identifier: String, radiusMeters: Double) async throws -> RegionConfiguration {
        throw NSError(domain: "LiveCurrentLocationResolver", code: 1)
    }
}
#endif
