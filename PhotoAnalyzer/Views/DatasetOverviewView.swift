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
            VStack(spacing: 12) {
                DashboardMetricRow(
                    title: "Most Used Camera",
                    value: mostUsedValue(in: statistics?.photosByCamera) ?? "--",
                    systemImage: "camera"
                )
                DashboardMetricRow(
                    title: "Most Used Lens",
                    value: mostUsedValue(in: statistics?.lensDistribution) ?? "--",
                    systemImage: "camera.macro"
                )

                VStack(alignment: .leading, spacing: 8) {
                    Label("Top Focal Lengths", systemImage: "scope")
                        .foregroundStyle(.secondary)

                    if topFocalLengthUsage.isEmpty {
                        Text("--")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(topFocalLengthUsage.enumerated()), id: \.offset) { index, usage in
                            HStack {
                                Text("#\(index + 1)")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .leading)

                                Text("\(usage.focalLength) mm: \(usage.count)")
                                    .fontWeight(.medium)

                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                DashboardMetricRow(
                    title: "Photo Types",
                    value: photoTypesText,
                    systemImage: "rectangle.stack"
                )
                DashboardMetricRow(
                    title: "Cameras Detected",
                    value: countText(statistics?.photosByCamera.count),
                    systemImage: "camera"
                )
                DashboardMetricRow(
                    title: "Lenses Detected",
                    value: countText(statistics?.lensDistribution.count),
                    systemImage: "camera.macro"
                )
            }
            .padding(.vertical, 6)
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
