import Foundation
import SenseKitRuntime

#if canImport(CoreLocation)
import CoreLocation

@MainActor
final class LiveAddressSearchResolver: @unchecked Sendable {
    private let geocoder = CLGeocoder()

    func searchRegion(query: String, identifier: String, radiusMeters: Double) async throws -> RegionConfiguration {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw AddressSearchError.emptyQuery
        }

        let placemarks = try await geocodeAddressString(trimmedQuery)
        guard let location = placemarks.first?.location else {
            throw AddressSearchError.noMatch
        }

        return RegionConfiguration(
            identifier: identifier,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radiusMeters: radiusMeters
        )
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
