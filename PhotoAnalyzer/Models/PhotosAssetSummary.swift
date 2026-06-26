//
//  PhotosAssetSummary.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 26/06/2026.
//

import Foundation

#if canImport(CoreLocation)
import CoreLocation
#endif

/// Lightweight PhotoKit asset information used by the custom Photos picker.
nonisolated struct PhotosAssetSummary: Identifiable, Equatable, Sendable {
    let localIdentifier: String
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    let latitude: Double?
    let longitude: Double?
    let searchText: String

    var id: String {
        localIdentifier
    }
}

#if canImport(CoreLocation)
extension PhotosAssetSummary {
    var location: CLLocation? {
        guard let latitude, let longitude else {
            return nil
        }

        return CLLocation(latitude: latitude, longitude: longitude)
    }

    func isWithin(_ place: PhotosPlaceSearchResult) -> Bool {
        guard let location else {
            return false
        }

        return location.distance(from: place.location) <= place.radiusMeters
    }
}
#endif
