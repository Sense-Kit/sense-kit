import Foundation
import SenseKitRuntime

#if canImport(CoreLocation)
import CoreLocation
#if canImport(MapKit)
import MapKit
#endif

@MainActor
final class LiveAddressSearchResolver: @unchecked Sendable {
    private let geocoder = CLGeocoder()

    func searchRegion(query: String, identifier: String, radiusMeters: Double) async throws -> RegionConfiguration {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw AddressSearchError.emptyQuery
        }

        #if canImport(MapKit)
        if let region = try await searchWithMapKit(query: trimmedQuery, identifier: identifier, radiusMeters: radiusMeters) {
            return region
        }
        #endif

        return try await searchWithGeocoder(query: trimmedQuery, identifier: identifier, radiusMeters: radiusMeters)
    }

    private func geocodeAddressString(_ query: String) async throws -> [CLPlacemark] {
        try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(query) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: placemarks ?? [])
            }
        }
    }

    #if canImport(MapKit)
    private func searchWithMapKit(query: String, identifier: String, radiusMeters: Double) async throws -> RegionConfiguration? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else {
            return nil
        }

        let displayName = [
            item.name,
            item.placemark.title
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }

        return RegionConfiguration(
            identifier: identifier,
            displayName: displayName,
            latitude: item.placemark.coordinate.latitude,
            longitude: item.placemark.coordinate.longitude,
            radiusMeters: radiusMeters
        )
    }
    #endif

    private func searchWithGeocoder(query: String, identifier: String, radiusMeters: Double) async throws -> RegionConfiguration {
        let placemarks = try await geocodeAddressString(query)
        guard let placemark = placemarks.first, let location = placemark.location else {
            throw AddressSearchError.noMatch
        }

        let displayName = [
            placemark.name,
            placemark.thoroughfare,
            placemark.locality
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")

        return RegionConfiguration(
            identifier: identifier,
            displayName: displayName.isEmpty ? nil : displayName,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radiusMeters: radiusMeters
        )
    }
}

private enum AddressSearchError: LocalizedError {
    case emptyQuery
    case noMatch

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Enter a street, place, or address first."
        case .noMatch:
            return "SenseKit could not find that address."
        }
    }
}
#else
final class LiveAddressSearchResolver: @unchecked Sendable {
    func searchRegion(query: String, identifier: String, radiusMeters: Double) async throws -> RegionConfiguration {
        throw NSError(domain: "LiveAddressSearchResolver", code: 1)
    }
}
#endif
