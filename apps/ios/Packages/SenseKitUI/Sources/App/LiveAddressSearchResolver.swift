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
    #if canImport(MapKit)
    private var cachedCompletions: [String: MKLocalSearchCompletion] = [:]
    private var activeCompleterDelegate: LocalSearchCompleterDelegate?
    #endif

    func suggest(query: String) async throws -> [PlaceSearchSuggestion] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            #if canImport(MapKit)
            cachedCompletions = [:]
            #endif
            return []
        }

        #if canImport(MapKit)
        let suggestions = try await suggestWithMapKit(query: trimmedQuery)
        if !suggestions.isEmpty {
            return suggestions
        }
        #endif

        return []
    }

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

    func searchRegion(suggestion: PlaceSearchSuggestion, identifier: String, radiusMeters: Double) async throws -> RegionConfiguration {
        #if canImport(MapKit)
        if let completion = cachedCompletions[suggestion.id],
           let region = try await searchWithMapKitCompletion(completion, identifier: identifier, radiusMeters: radiusMeters) {
            return region
        }
        #endif

        return try await searchRegion(query: suggestion.query, identifier: identifier, radiusMeters: radiusMeters)
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
    private func suggestWithMapKit(query: String) async throws -> [PlaceSearchSuggestion] {
        let completer = MKLocalSearchCompleter()
        completer.resultTypes = [.address, .pointOfInterest]
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = LocalSearchCompleterDelegate(
                onResults: { completer in
                    var nextCache: [String: MKLocalSearchCompletion] = [:]
                    let suggestions = completer.results.prefix(6).compactMap { completion -> PlaceSearchSuggestion? in
                        let title = completion.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let subtitle = completion.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !title.isEmpty else {
                            return nil
                        }

                        let id = UUID().uuidString
                        nextCache[id] = completion
                        return PlaceSearchSuggestion(
                            id: id,
                            title: title,
                            subtitle: subtitle,
                            query: [title, subtitle].filter { !$0.isEmpty }.joined(separator: ", ")
                        )
                    }

                    self.cachedCompletions = nextCache
                    self.activeCompleterDelegate = nil
                    continuation.resume(returning: suggestions)
                },
                onError: { error in
                    self.activeCompleterDelegate = nil
                    continuation.resume(throwing: error)
                }
            )

            self.activeCompleterDelegate = delegate
            completer.delegate = delegate
            completer.queryFragment = query
        }
    }

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

    private func searchWithMapKitCompletion(
        _ completion: MKLocalSearchCompletion,
        identifier: String,
        radiusMeters: Double
    ) async throws -> RegionConfiguration? {
        let request = MKLocalSearch.Request(completion: completion)
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else {
            return nil
        }

        let displayName = [
            item.name,
            completion.title,
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

#if canImport(MapKit)
@MainActor
private final class LocalSearchCompleterDelegate: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {
    private let onResults: @MainActor (MKLocalSearchCompleter) -> Void
    private let onError: @MainActor (any Error) -> Void
    private var didResume = false

    init(
        onResults: @escaping @MainActor (MKLocalSearchCompleter) -> Void,
        onError: @escaping @MainActor (any Error) -> Void
    ) {
        self.onResults = onResults
        self.onError = onError
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard !didResume else { return }
        didResume = true
        onResults(completer)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        guard !didResume else { return }
        didResume = true
        onError(error)
    }
}
#endif

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
    func suggest(query: String) async throws -> [PlaceSearchSuggestion] {
        []
    }

    func searchRegion(query: String, identifier: String, radiusMeters: Double) async throws -> RegionConfiguration {
        throw NSError(domain: "LiveAddressSearchResolver", code: 1)
    }

    func searchRegion(suggestion: PlaceSearchSuggestion, identifier: String, radiusMeters: Double) async throws -> RegionConfiguration {
        try await searchRegion(query: suggestion.query, identifier: identifier, radiusMeters: radiusMeters)
    }
}
#endif
