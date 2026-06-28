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
    @Binding var exportDiagnosticReports: Bool
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

                MetadataCacheSettingsSection(
                    maximumSizeMB: $metadataCacheMaximumSizeMB,
                    usage: metadataCacheUsage,
                    refreshUsage: refreshMetadataCacheUsage,
                    clearCache: clearMetadataCache
                )

                Section("Optional Diagnostics") {
                    Toggle("Export quality report and diagnostic log", isOn: $exportDiagnosticReports)
                        .help("Write optional quality_report.json and analysis_log.json files next to generated AI packages")

                    Text("Writes metadata completeness counts and run diagnostics into the package folder. These files are not included in the AI package ZIP.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .formStyle(.grouped)
            .disabled(!canEditSettings)
        }
        .padding(24)
        .frame(width: 720, height: 720, alignment: .topLeading)
        .onAppear(perform: refreshMetadataCacheUsage)
    }

    private var outputFolderText: String {
        outputFolderURL.path
    }
}
