//
//  DatasetActionView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import SwiftUI
import PhotosUI

/// Top action area for choosing a dataset and generating an AI package.
struct DatasetActionView: View {
	private enum Layout {
		static let secondaryActionsColumnWidth: CGFloat = 150
		static let actionColumnWidth: CGFloat = 280
	}

	let datasetState: DatasetUIState
	let outputFolderURL: URL?
	let sourceIconName: String
	let sourceText: String
	let sourcePath: String?
	let isSourcePlaceholder: Bool
	let canAnalyze: Bool
	let isAnalyzing: Bool
	let isCountingSupportedFiles: Bool
	@Binding var includeSubfolders: Bool
	@Binding var useCurrentPhotosEncoding: Bool
	@Binding var selectedPhotoItems: [PhotosPickerItem]
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
							iconName: sourceIconName,
							title: "Source",
							text: sourceText,
							path: sourcePath,
							isPlaceholder: isSourcePlaceholder
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

					VStack(alignment: .trailing, spacing: 8) {
						Button(action: selectFolder) {
							Label("Select Folder", systemImage: "folder.badge.plus")
						}
						.disabled(isAnalyzing || isCountingSupportedFiles)

						PhotosPicker(
							selection: $selectedPhotoItems,
							maxSelectionCount: nil,
							matching: .images,
							preferredItemEncoding: useCurrentPhotosEncoding ? .current : .automatic
						) {
							Label("Select Photos", systemImage: "photo.on.rectangle.angled")
						}
						.disabled(isAnalyzing || isCountingSupportedFiles)

						Button(action: selectOutputFolder) {
							Label("Select Output", systemImage: "tray.and.arrow.down")
						}
						.disabled(isAnalyzing)

						settingsMenu
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

	private var settingsMenu: some View {
		Menu {
			Toggle("Include folder subfolders", isOn: $includeSubfolders)
				.disabled(isAnalyzing || isCountingSupportedFiles)

			Toggle("Use current Photos encoding", isOn: $useCurrentPhotosEncoding)
				.disabled(isAnalyzing || isCountingSupportedFiles)
		} label: {
			Label("Settings", systemImage: "gearshape")
		}
		.disabled(isAnalyzing || isCountingSupportedFiles)
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
			.disabled(!canAnalyze || isCountingSupportedFiles)
			.frame(maxWidth: .infinity)
		}
	}
}
