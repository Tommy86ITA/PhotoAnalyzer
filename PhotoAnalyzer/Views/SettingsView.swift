//
//  SettingsView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 20/06/2026.
//

import SwiftUI

/// Dedicated settings surface for persisted analysis preferences.
struct SettingsView: View {
    @Binding var useUnmodifiedPhotosOriginals: Bool
    @Binding var downloadMissingPhotosOriginals: Bool
    @Binding var metadataCacheMaximumSizeMB: Int
    let metadataCacheUsage: MetadataCacheUsage
    let outputFolderURL: URL
    let canEditSettings: Bool
    let selectOutputFolder: () -> Void
    let refreshMetadataCacheUsage: () -> Void
    let clearMetadataCache: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Settings")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button("Done", action: dismiss)
                    .keyboardShortcut(.defaultAction)
                    .help("Close Settings")
            }

            Divider()

            Form {
                Section("Output") {
                    HStack(spacing: 10) {
                        Label("AI package folder", systemImage: "tray.full")

                        Spacer(minLength: 12)

                        Text(outputFolderText)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(outputFolderText)

                        CopyPathButton(path: outputFolderURL.path)

                        Button("Choose...", action: selectOutputFolder)
                            .disabled(!canEditSettings)
                            .help(canEditSettings ? "Choose Output Folder" : "Settings cannot be changed while analysis is running")
                    }
                }

                Section("Photos Library") {
                    Toggle("Use unmodified originals", isOn: $useUnmodifiedPhotosOriginals)
                        .help("Export original, unedited Photos assets when available")
                    Toggle("Download missing iCloud originals", isOn: $downloadMissingPhotosOriginals)
                        .help("Allow Photos to download missing originals from iCloud during analysis")

                    if downloadMissingPhotosOriginals {
                        Label {
                            Text("Downloading high-resolution files from iCloud can make analysis slower. Be careful when using metered or limited network connections.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                Section("Metadata Cache") {
                    Picker("Maximum size", selection: normalizedMetadataCacheLimit) {
                        ForEach(MetadataCacheSizeLimit.allCases) { limit in
                            Text(limit.displayName).tag(limit.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .help("Limit disk usage for cached ExifTool metadata")

                    HStack(spacing: 10) {
                        Label(metadataCacheUsageText, systemImage: "externaldrive")

                        Spacer()

                        Button("Refresh", action: refreshMetadataCacheUsage)
                            .help("Refresh Cache Usage")

                        Button("Clear", action: clearMetadataCache)
                            .disabled(metadataCacheUsage.entryCount == 0)
                            .help("Clear Metadata Cache")
                    }
                }
            }
            .formStyle(.grouped)
            .disabled(!canEditSettings)
        }
        .padding(24)
        .frame(width: 640, height: 520, alignment: .topLeading)
        .onAppear(perform: refreshMetadataCacheUsage)
    }

    private var outputFolderText: String {
        outputFolderURL.path
    }

    private var normalizedMetadataCacheLimit: Binding<Int> {
        Binding(
            get: { MetadataCacheSizeLimit.normalizedRawValue(metadataCacheMaximumSizeMB) },
            set: { metadataCacheMaximumSizeMB = MetadataCacheSizeLimit.normalizedRawValue($0) }
        )
    }

    private var metadataCacheUsageText: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        let size = formatter.string(fromByteCount: metadataCacheUsage.byteCount)
        return "\(size) used across \(metadataCacheUsage.entryCount) entries"
    }
}
