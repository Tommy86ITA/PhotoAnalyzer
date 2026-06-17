//
//  PhotoStatisticsTextReporter.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation

/// Prints aggregate photo statistics as a text report for development diagnostics.
final class PhotoStatisticsTextReporter {
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

    /// Creates a text reporter.
    nonisolated init() {}

    /// Prints a text report for aggregate photo statistics.
    /// - Parameter statistics: The statistics to print.
    nonisolated func printReport(for statistics: PhotoStatistics) {
        print("")
        print("Photo Statistics")
        print("Total photos: \(statistics.totalPhotos)")
        print("By type:")

        for photoType in orderedPhotoTypes {
            print("- \(label(for: photoType)): \(statistics.photosByType[photoType, default: 0])")
        }

        print("By camera:")
        for camera in statistics.photosByCamera.keys.sorted() {
            print("- \(camera): \(statistics.photosByCamera[camera, default: 0])")
        }

        print("Average ISO: \(formatted(statistics.averageISO))")
        print("Average 35mm focal length: \(formatted(statistics.averageFocalLength35mmEquivalent))")

        print("")
        print("ISO distribution:")
        for iso in statistics.isoDistribution.keys.sorted() {
            print("- ISO \(iso): \(statistics.isoDistribution[iso, default: 0])")
        }

        print("")
        print("35mm focal length distribution:")
        for focalLength in statistics.focalLength35mmDistribution.keys.sorted() {
            print("- \(focalLength) mm: \(statistics.focalLength35mmDistribution[focalLength, default: 0])")
        }

        print("")
        print("Aperture distribution:")
        for aperture in sortedNumericLabels(statistics.apertureDistribution.keys, prefix: "f/") {
            print("- \(aperture): \(statistics.apertureDistribution[aperture, default: 0])")
        }

        print("")
        print("Shutter speed distribution:")
        for shutterSpeed in sortedShutterSpeedLabels(statistics.shutterSpeedDistribution.keys) {
            print("- \(shutterSpeed): \(statistics.shutterSpeedDistribution[shutterSpeed, default: 0])")
        }

        print("")
        print("Lens distribution:")
        for lens in statistics.lensDistribution.keys.sorted() {
            print("- \(lens): \(statistics.lensDistribution[lens, default: 0])")
        }
    }

    /// Returns a display label for a photo type.
    /// - Parameter photoType: The photo type to display.
    /// - Returns: A human-readable label.
    nonisolated private func label(for photoType: PhotoType) -> String {
        switch photoType {
        case .standard:
            return "Standard"
        case .panorama:
            return "Panorama"
        case .livePhoto:
            return "Live Photo"
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

    /// Formats an optional numeric statistic for logging.
    /// - Parameter value: The value to format.
    /// - Returns: A formatted value, or `--` when unavailable.
    nonisolated private func formatted(_ value: Double?) -> String {
        guard let value else {
            return "--"
        }

        return String(format: "%.2f", value)
    }

    /// Sorts labels that contain a numeric value after a fixed prefix.
    /// - Parameters:
    ///   - labels: The labels to sort.
    ///   - prefix: The prefix to remove before parsing.
    /// - Returns: Labels sorted by numeric value.
    nonisolated private func sortedNumericLabels(_ labels: Dictionary<String, Int>.Keys, prefix: String) -> [String] {
        labels.sorted {
            numericValue(from: $0, removing: prefix) < numericValue(from: $1, removing: prefix)
        }
    }

    /// Sorts shutter speed labels from fastest to slowest.
    /// - Parameter labels: The labels to sort.
    /// - Returns: Labels sorted by exposure duration.
    nonisolated private func sortedShutterSpeedLabels(_ labels: Dictionary<String, Int>.Keys) -> [String] {
        labels.sorted {
            shutterSpeedValue(from: $0) < shutterSpeedValue(from: $1)
        }
    }

    /// Parses a numeric value from a display label.
    /// - Parameters:
    ///   - label: The label to parse.
    ///   - prefix: A prefix to remove before parsing.
    /// - Returns: The parsed number, or infinity when parsing fails.
    nonisolated private func numericValue(from label: String, removing prefix: String) -> Double {
        Double(label.replacingOccurrences(of: prefix, with: "")) ?? .infinity
    }

    /// Converts a shutter speed label back to seconds for sorting.
    /// - Parameter label: The shutter speed label to parse.
    /// - Returns: Exposure duration in seconds.
    nonisolated private func shutterSpeedValue(from label: String) -> Double {
        let parts = label.split(separator: "/")

        if parts.count == 2,
           let numerator = Double(parts[0]),
           let denominator = Double(parts[1]),
           denominator != 0 {
            return numerator / denominator
        }

        let secondsLabel = label.replacingOccurrences(of: " s", with: "")
        return Double(secondsLabel) ?? .infinity
    }
}
