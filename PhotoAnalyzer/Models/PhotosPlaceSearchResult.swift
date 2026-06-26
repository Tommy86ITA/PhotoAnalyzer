//
//  PhotosPlaceSearchResult.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 26/06/2026.
//

import Foundation

#if canImport(CoreLocation)
import CoreLocation
#endif

nonisolated struct PhotosPlaceSearchResult: Identifiable, Equatable, Sendable {
    let query: String
    let displayName: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double

    var id: String {
        "\(query)-\(latitude)-\(longitude)-\(radiusMeters)"
    }
}

#if canImport(CoreLocation)
extension PhotosPlaceSearchResult {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}
#endif
