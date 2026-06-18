//
//  DatasetActionView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import SwiftUI

/// Top action area for choosing a dataset and generating an AI package.
struct DatasetActionView: View {
	private enum Layout {
		static let includeSubfoldersColumnWidth: CGFloat = 170
		static let secondaryActionsColumnWidth: CGFloat = 150
		static let actionColumnWidth: CGFloat = 280
	}

	let datasetState: DatasetUIState
	let outputFolderURL: URL?
	let isAnalyzing: Bool
	let isCountingSupportedFiles: Bool
	@Binding var includeSubfolders: Bool
	let selectFolder: () -> Void
	let selectOutputFolder: () -> Void
	let analyze: () -> Void
	let cancelAnalysis: () -> Void

	var body: some View {
		GroupBox("Dataset") {
			VStack(alignment: .leading, spacing: 12) {
				HStack(alignment: .center, spacing: 18) {
					VStack(alignment: .leading, spacing: 10) {
						pathRow(
							iconName: datasetState.folderURL == nil ? "folder" : "folder.fill",
							title: "Source",
							text: datasetState.folderPathText,
							path: datasetState.folderURL?.path,
							isPlaceholder: datasetState.folderURL == nil
						)

						pathRow(
							iconName: outputFolderURL == nil ? "tray" : "tray.full",
							title: "Output",
							text: outputFolderText,
							path: outputFolderURL?.path,
							isPlaceholder: outputFolderURL == nil
						)
					}
					.frame(maxWidth: .infinity, alignment: .leading)

					VStack(alignment: .leading, spacing: 10) {
						Toggle("Include subfolders", isOn: $includeSubfolders)
							.toggleStyle(.checkbox)
							.disabled(isAnalyzing || isCountingSupportedFiles)

						Color.clear
							.frame(height: 24)
					}
					.frame(width: Layout.includeSubfoldersColumnWidth, alignment: .leading)

					VStack(alignment: .trailing, spacing: 8) {
						Button(action: selectFolder) {
							Label("Select Source", systemImage: "folder.badge.plus")
						}
						.disabled(isAnalyzing || isCountingSupportedFiles)

						Button(action: selectOutputFolder) {
							Label("Select Output", systemImage: "tray.and.arrow.down")
						}
						.disabled(isAnalyzing)
					}
					.frame(width: Layout.secondaryActionsColumnWidth, alignment: .trailing)

					analysisButton
						.frame(width: Layout.actionColumnWidth)
				}

				Divider()

				metricsRow
			}
			.padding(.vertical, 2)
		}
	}

	private var outputFolderText: String {
		outputFolderURL?.path ?? "Same as dataset folder"
	}

	private func pathRow(
		iconName: String,
		title: String,
		text: String,
		path: String?,
		isPlaceholder: Bool
	) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 10) {
			Image(systemName: iconName)
				.foregroundStyle(.secondary)
				.frame(width: 18)

			Text(title)
				.font(.footnote.weight(.semibold))
				.foregroundStyle(.secondary)
				.frame(width: 52, alignment: .leading)

			Text(text)
				.font(.system(.body, design: .monospaced))
				.foregroundStyle(isPlaceholder ? .secondary : .primary)
				.lineLimit(1)
				.truncationMode(.middle)
				.textSelection(.enabled)
				.help(path ?? text)

			CopyPathButton(path: path)
		}
		.help(path ?? text)
	}

	private var metricsRow: some View {
		HStack(alignment: .center, spacing: 14) {
			Label("Supported: \(datasetState.supportedFilesText)", systemImage: "photo.stack")
				.help("Supported image files found in the selected dataset.")
			Label("Analyzed: \(datasetState.analyzedPhotosText)", systemImage: "checkmark.circle")
				.help("Photos successfully processed during the current analysis.")
			Label(datasetState.analysisStatus.displayText, systemImage: "waveform.path.ecg")
				.help("Current dataset analysis status.")
		}
		.font(.footnote)
		.foregroundStyle(.secondary)
	}

	@ViewBuilder
	private var analysisButton: some View {
		if isAnalyzing {
			Button(role: .cancel, action: cancelAnalysis) {
				Label("Cancel Analysis", systemImage: "xmark.circle")
			}
			.buttonStyle(.borderedProminent)
			.tint(.red)
			.frame(maxWidth: .infinity)
		} else {
			Button(action: analyze) {
				Label("Analyze & Generate AI Package", systemImage: "shippingbox")
			}
			.buttonStyle(.borderedProminent)
			.disabled(datasetState.folderURL == nil || datasetState.supportedFileCount == 0 || isCountingSupportedFiles)
			.frame(maxWidth: .infinity)
		}
	}
}
