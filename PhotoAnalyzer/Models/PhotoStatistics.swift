//
//  PhotoStatistics.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 15/06/2026.
//

import Foundation

/// Aggregate statistics computed from a collection of photo information models.
nonisolated struct PhotoStatistics {
    /// The total number of photos included in the statistics.
    let totalPhotos: Int

    /// Counts grouped by primary photo type.
    let photosByType: [PhotoType: Int]

    /// Counts grouped by camera model.
    let photosByCamera: [String: Int]

    /// Counts grouped by ISO value.
    let isoDistribution: [Int: Int]

    /// Counts grouped by 35mm equivalent focal length.
    let focalLength35mmDistribution: [Int: Int]

    /// Counts grouped by aperture display value.
    let apertureDistribution: [String: Int]

    /// Counts grouped by shutter speed display value.
    let shutterSpeedDistribution: [String: Int]

    /// Counts grouped by lens model.
    let lensDistribution: [String: Int]

    /// The average ISO value computed from photos that have ISO metadata.
    let averageISO: Double?

    /// The average 35mm equivalent focal length computed from photos that have focal length metadata.
    let averageFocalLength35mmEquivalent: Double?
}
