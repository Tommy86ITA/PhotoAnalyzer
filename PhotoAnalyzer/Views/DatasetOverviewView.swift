//
//  DatasetOverviewView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import SwiftUI

/// Compact objective overview for the analyzed dataset.
struct DatasetOverviewView: View {
    let statistics: PhotoStatistics?

    var body: some View {
        GroupBox("Dataset Overview") {
            VStack(spacing: 8) {
                DashboardMetricRow(
                    title: "Most Used Camera",
                    value: mostUsedValue(in: statistics?.photosByCamera) ?? "--",
                    systemImage: "camera",
                    helpText: "Camera model with the highest number of analyzed photos."
                )
                DashboardMetricRow(
                    title: "Most Used Lens",
                    value: mostUsedValue(in: statistics?.lensDistribution) ?? "--",
                    systemImage: "camera.macro",
                    helpText: "Lens model with the highest number of analyzed photos."
                )

                DashboardMetricRow(
                    title: "Most Used Focal Lengths",
                    value: topFocalLengthsText,
                    systemImage: "scope",
                    helpText: "Most frequent 35mm-equivalent focal lengths and their photo counts."
                )

                Divider()

                DashboardMetricRow(
                    title: "Photo Types",
                    value: photoTypesText,
                    systemImage: "rectangle.stack",
                    helpText: "Photo categories detected in the analyzed metadata."
                )
                DashboardMetricRow(
                    title: "Cameras Detected",
                    value: countText(statistics?.photosByCamera.count),
                    systemImage: "camera",
                    helpText: "Number of distinct camera models found in the dataset."
                )
                DashboardMetricRow(
                    title: "Lenses Detected",
                    value: countText(statistics?.lensDistribution.count),
                    systemImage: "camera.macro",
                    helpText: "Number of distinct lens models found in the dataset."
                )
            }
            .padding(.vertical, 4)
        }
    }

    private var topFocalLengthUsage: [(focalLength: Int, count: Int)] {
        guard let focalLengthDistribution = statistics?.focalLength35mmDistribution else {
            return []
        }

        return focalLengthDistribution
            .sorted {
                if $0.value == $1.value {
                    return $0.key < $1.key
                }

                return $0.value > $1.value
            }
            .prefix(3)
            .map { (focalLength: $0.key, count: $0.value) }
    }

    private var photoTypesText: String {
        guard let statistics else {
            return "--"
        }

        let labels = PhotoType.overviewDisplayOrder.compactMap { photoType in
            statistics.photosByType[photoType, default: 0] > 0 ? label(for: photoType) : nil
        }

        return labels.isEmpty ? "--" : labels.joined(separator: ", ")
    }

    private var topFocalLengthsText: String {
        guard !topFocalLengthUsage.isEmpty else {
            return "--"
        }

        return topFocalLengthUsage
            .map { "\($0.focalLength) mm: \($0.count)" }
            .joined(separator: ", ")
    }

    private func mostUsedValue(in counts: [String: Int]?) -> String? {
        guard let counts, !counts.isEmpty else {
            return nil
        }

        return counts
            .sorted {
                if $0.value == $1.value {
                    return $0.key < $1.key
                }

                return $0.value > $1.value
            }
            .first?
            .key
    }

    private func countText(_ count: Int?) -> String {
        guard let count else {
            return "--"
        }

        return String(count)
    }

    private func label(for photoType: PhotoType) -> String {
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
}

private extension PhotoType {
    static let overviewDisplayOrder: [PhotoType] = [
        .standard,
        .portrait,
        .hdr,
        .panorama,
        .livePhoto,
        .spatial,
        .screenshot
    ]
}
