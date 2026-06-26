//
//  PhotosPlaceSearchService.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 26/06/2026.
//

import Foundation

#if canImport(CoreLocation)
import CoreLocation
#endif

#if canImport(MapKit)
import MapKit
#endif

enum PhotosPlaceSearchError: LocalizedError {
    case unavailable
    case emptyQuery
    case notFound

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Location search is not available on this device."
        case .emptyQuery:
            return "Enter a place to search."
        case .notFound:
            return "No matching place was found."
        }
    }
}

nonisolated struct PhotosPlaceSearchService: Sendable {
    private static let cache = PhotosPlaceSearchCache()
    private let radiusMeters: Double

    init(radiusMeters: Double = 50_000) {
        self.radiusMeters = radiusMeters
    }

    func search(query: String) async throws -> PhotosPlaceSearchResult {
        #if canImport(MapKit)
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalizedQuery.isEmpty else {
            throw PhotosPlaceSearchError.emptyQuery
        }

        if let cached = await Self.cache.result(for: normalizedQuery) {
            return cached
        }

        let result = try await Self.searchMapItem(query: query, radiusMeters: radiusMeters)
        await Self.cache.store(result, for: normalizedQuery)
        return result
        #else
        throw PhotosPlaceSearchError.unavailable
        #endif
    }
}

#if canImport(MapKit)
private extension PhotosPlaceSearchService {
    static func searchMapItem(
        query: String,
        radiusMeters: Double
    ) async throws -> PhotosPlaceSearchResult {
        let request = MKLocalSearch.Request(naturalLanguageQuery: query)
        request.resultTypes = [.address, .pointOfInterest]
        let search = MKLocalSearch(request: request)

        return try await withCheckedThrowingContinuation { continuation in
            search.start { response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let mapItem = response?.mapItems.first else {
                    continuation.resume(throwing: PhotosPlaceSearchError.notFound)
                    return
                }

                let coordinate = mapItem.location.coordinate
                continuation.resume(returning: PhotosPlaceSearchResult(
                    query: query,
                    displayName: displayName(for: mapItem, fallback: query),
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    radiusMeters: radiusMeters
                ))
            }
        }
    }

    static func displayName(for mapItem: MKMapItem, fallback: String) -> String {
        [
            mapItem.name,
            mapItem.addressRepresentations?.cityWithContext(.automatic),
            mapItem.addressRepresentations?.regionName
        ]
            .compactMap { $0 }
            .reduce(into: [String]()) { parts, part in
                if !parts.contains(part) {
                    parts.append(part)
                }
            }
            .joined(separator: ", ")
            .nilIfEmpty ?? fallback
    }
}

private actor PhotosPlaceSearchCache {
    private var resultsByQuery: [String: PhotosPlaceSearchResult] = [:]

    func result(for query: String) -> PhotosPlaceSearchResult? {
        resultsByQuery[query]
    }

    func store(_ result: PhotosPlaceSearchResult, for query: String) {
        resultsByQuery[query] = result
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
#endif
