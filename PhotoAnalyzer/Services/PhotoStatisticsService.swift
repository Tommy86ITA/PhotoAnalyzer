//
//  PhotoStatisticsService.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 15/06/2026.
//

import Foundation

/// A service responsible for computing aggregate statistics from photo information models.
final class PhotoStatisticsService {
    /// The stable display order for photo type statistics.
    private let orderedPhotoTypes: [PhotoType] = [
        .standard,
        .panorama,
        .livePhoto,
        .portrait,
        .screenshot,
        .spatial,
        .hdr
    ]

    /// Creates a photo statistics service.
    nonisolated init() {}

    /// Builds aggregate statistics from a collection of photos.
    /// - Parameter photos: The photo information models to analyze.
    /// - Returns: Aggregate photo statistics.
    nonisolated func buildStatistics(from photos: [PhotoInfo]) -> PhotoStatistics {
        let statistics = PhotoStatistics(
            totalPhotos: photos.count,
            photosByType: photoTypeCounts(from: photos),
            photosByCamera: cameraCounts(from: photos),
            isoDistribution: isoDistribution(from: photos),
            focalLength35mmDistribution: focalLength35mmDistribution(from: photos),
            apertureDistribution: apertureDistribution(from: photos),
            shutterSpeedDistribution: shutterSpeedDistribution(from: photos),
            lensDistribution: lensDistribution(from: photos),
            averageISO: averageISO(from: photos),
            averageFocalLength35mmEquivalent: averageFocalLength35mmEquivalent(from: photos)
        )

        PhotoStatisticsTextReporter().printReport(for: statistics)
        return statistics
    }

    /// Counts photos by primary photo type.
    /// - Parameter photos: The photo information models to analyze.
    /// - Returns: A dictionary keyed by photo type.
    nonisolated private func photoTypeCounts(from photos: [PhotoInfo]) -> [PhotoType: Int] {
        var counts = Dictionary(uniqueKeysWithValues: orderedPhotoTypes.map { ($0, 0) })

        for photo in photos {
            counts[photo.photoType, default: 0] += 1
        }

        return counts
    }

    /// Counts photos by camera model.
    /// - Parameter photos: The photo information models to analyze.
    /// - Returns: A dictionary keyed by readable camera name.
    nonisolated private func cameraCounts(from photos: [PhotoInfo]) -> [String: Int] {
        var counts: [String: Int] = [:]

        for photo in photos {
            let cameraName = cameraName(for: photo)
            counts[cameraName, default: 0] += 1
        }

        return counts
    }

    /// Counts photos by ISO value.
    /// - Parameter photos: The photo information models to analyze.
    /// - Returns: A dictionary keyed by ISO value.
    nonisolated private func isoDistribution(from photos: [PhotoInfo]) -> [Int: Int] {
        var counts: [Int: Int] = [:]

        for iso in photos.compactMap(\.iso) {
            counts[iso, default: 0] += 1
        }

        return counts
    }

    /// Counts photos by rounded 35mm equivalent focal length.
    /// - Parameter photos: The photo information models to analyze.
    /// - Returns: A dictionary keyed by focal length in millimeters.
    nonisolated private func focalLength35mmDistribution(from photos: [PhotoInfo]) -> [Int: Int] {
        var counts: [Int: Int] = [:]

        for focalLength in photos.compactMap(\.focalLength35mmEquivalent) {
            counts[Int(focalLength.rounded()), default: 0] += 1
        }

        return counts
    }

    /// Counts photos by aperture value.
    /// - Parameter photos: The photo information models to analyze.
    /// - Returns: A dictionary keyed by formatted f-number.
    nonisolated private func apertureDistribution(from photos: [PhotoInfo]) -> [String: Int] {
        var counts: [String: Int] = [:]

        for aperture in photos.compactMap(\.aperture) {
            counts[apertureLabel(for: aperture), default: 0] += 1
        }

        return counts
    }

    /// Counts photos by shutter speed.
    /// - Parameter photos: The photo information models to analyze.
    /// - Returns: A dictionary keyed by formatted shutter speed.
    nonisolated private func shutterSpeedDistribution(from photos: [PhotoInfo]) -> [String: Int] {
        var counts: [String: Int] = [:]

        for exposureTime in photos.compactMap(\.exposureTime) {
            counts[shutterSpeedLabel(for: exposureTime), default: 0] += 1
        }

        return counts
    }

    /// Counts photos by lens model.
    /// - Parameter photos: The photo information models to analyze.
    /// - Returns: A dictionary keyed by lens model or a fallback label.
    nonisolated private func lensDistribution(from photos: [PhotoInfo]) -> [String: Int] {
        var counts: [String: Int] = [:]

        for photo in photos {
            counts[lensDisplayName(for: photo), default: 0] += 1
        }

        return counts
    }

    /// Computes the average ISO from available values.
    /// - Parameter photos: The photo information models to analyze.
    /// - Returns: The average ISO, or `nil` when no ISO values are available.
    nonisolated private func averageISO(from photos: [PhotoInfo]) -> Double? {
        let values = photos.compactMap { $0.iso }.map(Double.init)
        return average(values)
    }

    /// Computes the average 35mm equivalent focal length from available values.
    /// - Parameter photos: The photo information models to analyze.
    /// - Returns: The average focal length, or `nil` when no values are available.
    nonisolated private func averageFocalLength35mmEquivalent(from photos: [PhotoInfo]) -> Double? {
        average(photos.compactMap { $0.focalLength35mmEquivalent })
    }

    /// Computes an average for a list of numeric values.
    /// - Parameter values: The values to average.
    /// - Returns: The average value, or `nil` when the list is empty.
    nonisolated private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +) / Double(values.count)
    }

    /// Builds a readable camera name from make and model metadata.
    /// - Parameter photo: The photo information model to inspect.
    /// - Returns: A readable camera name.
    nonisolated private func cameraName(for photo: PhotoInfo) -> String {
        let make = photo.cameraMake?.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = photo.cameraModel?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (make?.isEmpty == false ? make : nil, model?.isEmpty == false ? model : nil) {
        case let (make?, model?) where model.localizedCaseInsensitiveContains(make):
            return model
        case let (make?, model?):
            return "\(make) \(model)"
        case let (_, model?):
            return model
        case let (make?, nil):
            return make
        default:
            return "Unknown Camera"
        }
    }

    /// Builds a readable lens display name from photo metadata.
    /// - Parameter photo: The photo information model to inspect.
    /// - Returns: A readable lens name, or a built-in lens fallback for fixed-lens cameras.
    nonisolated private func lensDisplayName(for photo: PhotoInfo) -> String {
        let lens = photo.lensModel?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let lens, !lens.isEmpty {
            return lens
        }

        let camera = cameraName(for: photo)
        if camera != "Unknown Camera" {
            return "\(camera) built-in lens"
        }

        return "Unknown"
    }

    /// Formats an aperture value as a readable f-number.
    /// - Parameter aperture: The aperture value to format.
    /// - Returns: A display label such as `f/1.8`.
    nonisolated private func apertureLabel(for aperture: Double) -> String {
        "f/\(formattedNumber(aperture))"
    }

    /// Formats an exposure time as a readable shutter speed.
    /// - Parameter exposureTime: The exposure time in seconds.
    /// - Returns: A display label such as `1/60` or `2 s`.
    nonisolated private func shutterSpeedLabel(for exposureTime: Double) -> String {
        guard exposureTime > 0 else {
            return "--"
        }

        if exposureTime < 1 {
            let denominator = Int((1 / exposureTime).rounded())
            return "1/\(denominator)"
        }

        return "\(formattedNumber(exposureTime)) s"
    }

    /// Formats a number without unnecessary trailing zeroes.
    /// - Parameter value: The number to format.
    /// - Returns: A compact decimal string.
    nonisolated private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

}
