//
//  AIStatisticsPayload.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation

/// A JSON-friendly representation of `PhotoStatistics` for AI analysis package exports.
nonisolated struct AIStatisticsPayload: Encodable {
    let totalPhotos: Int
    let photosByType: [String: Int]
    let photosByCamera: [String: Int]
    let isoDistribution: [Int: Int]
    let focalLength35mmDistribution: [Int: Int]
    let apertureDistribution: [String: Int]
    let shutterSpeedDistribution: [String: Int]
    let lensDistribution: [String: Int]
    let averageISO: Double?
    let averageFocalLength35mmEquivalent: Double?

    init(statistics: PhotoStatistics) {
        totalPhotos = statistics.totalPhotos
        photosByType = Dictionary(
            uniqueKeysWithValues: statistics.photosByType.map { ($0.key.aiPackageValue, $0.value) }
        )
        photosByCamera = statistics.photosByCamera
        isoDistribution = statistics.isoDistribution
        focalLength35mmDistribution = statistics.focalLength35mmDistribution
        apertureDistribution = statistics.apertureDistribution
        shutterSpeedDistribution = statistics.shutterSpeedDistribution
        lensDistribution = statistics.lensDistribution
        averageISO = statistics.averageISO
        averageFocalLength35mmEquivalent = statistics.averageFocalLength35mmEquivalent
    }
}

private extension PhotoType {
    /// Stable string value used by AI analysis package exports.
    nonisolated var aiPackageValue: String {
        switch self {
        case .standard:
            return "Standard"
        case .panorama:
            return "Panorama"
        case .livePhoto:
            return "LivePhoto"
        case .portrait:
            return "Portrait"
        case .screenshot:
            return "Screenshot"
        case .spatial:
            return "Spatial"
        case .hdr:
            return "HDR"
        }
    }
}
