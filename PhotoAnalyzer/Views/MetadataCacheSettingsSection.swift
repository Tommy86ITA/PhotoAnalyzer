//
//  MetadataCacheSettingsSection.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 27/06/2026.
//

import SwiftUI

/// Settings controls for the on-disk ExifTool metadata cache.
struct MetadataCacheSettingsSection: View {
    @Binding var maximumSizeMB: Int
    let usage: MetadataCacheUsage
    let refreshUsage: () -> Void
    let clearCache: () -> Void

    var body: some View {
        Section("Metadata Cache") {
            Picker("Maximum size", selection: normalizedLimit) {
                ForEach(MetadataCacheSizeLimit.allCases) { limit in
                    Text(limit.displayName).tag(limit.rawValue)
                }
            }
            .pickerStyle(.menu)
            .help("Limit disk usage for cached ExifTool metadata")

            HStack(spacing: 10) {
                Label(usageText, systemImage: "externaldrive")

                Spacer()

                Button("Refresh", action: refreshUsage)
                    .help("Refresh Cache Usage")

                Button("Clear", action: clearCache)
                    .disabled(usage.entryCount == 0)
                    .help("Clear Metadata Cache")
            }
        }
    }

    private var normalizedLimit: Binding<Int> {
        Binding(
            get: { MetadataCacheSizeLimit.normalizedRawValue(maximumSizeMB) },
            set: { maximumSizeMB = MetadataCacheSizeLimit.normalizedRawValue($0) }
        )
    }

    private var usageText: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        let size = formatter.string(fromByteCount: usage.byteCount)
        return "\(size) used across \(usage.entryCount) entries"
    }
}
