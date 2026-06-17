//
//  DatasetActionView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import SwiftUI

/// Top action area for choosing a dataset and generating an AI package.
struct DatasetActionView: View {
    let datasetState: DatasetUIState
    let outputFolderURL: URL?
    let isAnalyzing: Bool
    let selectFolder: () -> Void
    let selectOutputFolder: () -> Void
    let analyze: () -> Void

    var body: some View {
        GroupBox("Dataset") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: datasetState.folderURL == nil ? "folder" : "folder.fill")
                        .foregroundStyle(.secondary)

                    Text(datasetState.folderPathText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(datasetState.folderURL == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    CopyPathButton(path: datasetState.folderURL?.path)

                    Spacer(minLength: 0)

                    Button(action: selectFolder) {
                        Label("Select Folder", systemImage: "folder.badge.plus")
                    }
                    .disabled(isAnalyzing)

                    Button(action: analyze) {
                        Label("Analyze & Generate AI Package", systemImage: "shippingbox")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(datasetState.folderURL == nil || datasetState.supportedFileCount == 0 || isAnalyzing)
                }

                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: outputFolderURL == nil ? "tray" : "tray.full")
                        .foregroundStyle(.secondary)
                        .frame(width: 18)

                    Text("Output")
                        .foregroundStyle(.secondary)

                    Text(outputFolderText)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(outputFolderURL == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    CopyPathButton(path: outputFolderURL?.path)

                    Spacer(minLength: 0)

                    Button(action: selectOutputFolder) {
                        Label("Select Output Folder", systemImage: "folder.badge.plus")
                    }
                    .disabled(isAnalyzing)
                }
                .font(.footnote)

                HStack(alignment: .center, spacing: 14) {
                    Label("Supported: \(datasetState.supportedFilesText)", systemImage: "photo.stack")
                    Label("Analyzed: \(datasetState.analyzedPhotosText)", systemImage: "checkmark.circle")
                    Label(datasetState.analysisStatus.displayText, systemImage: "waveform.path.ecg")

                    Spacer(minLength: 0)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    private var outputFolderText: String {
        outputFolderURL?.path ?? "Same as dataset folder"
    }
}
