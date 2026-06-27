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
    let outputFolderURL: URL
    let canEditSettings: Bool
    let selectOutputFolder: () -> Void
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
            }
            .formStyle(.grouped)
            .disabled(!canEditSettings)
        }
        .padding(24)
        .frame(width: 640, height: 400, alignment: .topLeading)
    }

    private var outputFolderText: String {
        outputFolderURL.path
    }
}
