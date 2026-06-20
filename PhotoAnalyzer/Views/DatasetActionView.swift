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
		static let actionColumnWidth: CGFloat = 310
		static let secondaryButtonSize: CGFloat = 32
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
	let useCurrentPhotosEncoding: Bool
	@Binding var selectedPhotoItems: [PhotosPickerItem]
	let selectFolder: () -> Void
	let selectOutputFolder: () -> Void
	let openSettings: () -> Void
	let analyze: () -> Void
	let cancelAnalysis: () -> Void

	var body: some View {
		GroupBox("Dataset") {
			VStack(alignment: .leading, spacing: 10) {
				HStack(alignment: .top, spacing: 18) {
					VStack(alignment: .leading, spacing: 8) {
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

					VStack(alignment: .trailing, spacing: 10) {
						analysisButton
							.frame(width: Layout.actionColumnWidth)

						secondaryActions
					}
					.frame(width: Layout.actionColumnWidth, alignment: .trailing)
				}

				Divider()

				metricsRow
			}
			.padding(.vertical, 2)
		}
	}

	private var secondaryActions: some View {
		HStack(spacing: 6) {
			compactButton(
				title: "Select Folder",
				systemImage: "folder.badge.plus",
				action: selectFolder
			)
			.disabled(isAnalyzing || isCountingSupportedFiles)

			PhotosPicker(
				selection: $selectedPhotoItems,
				maxSelectionCount: nil,
				matching: .images,
				preferredItemEncoding: useCurrentPhotosEncoding ? .current : .automatic
			) {
				Label("Select Photos", systemImage: "photo.on.rectangle.angled")
					.labelStyle(.iconOnly)
					.frame(width: Layout.secondaryButtonSize, height: Layout.secondaryButtonSize)
			}
			.buttonStyle(.bordered)
			.disabled(isAnalyzing || isCountingSupportedFiles)
			.help("Select Photos")

			compactButton(
				title: "Select Output",
				systemImage: "tray.and.arrow.down",
				action: selectOutputFolder
			)
			.disabled(isAnalyzing)

			compactButton(
				title: "Settings",
				systemImage: "gearshape",
				action: openSettings
			)
		}
	}

	private func compactButton(
		title: String,
		systemImage: String,
		action: @escaping () -> Void
	) -> some View {
		Button(action: action) {
			Label(title, systemImage: systemImage)
				.labelStyle(.iconOnly)
				.frame(width: Layout.secondaryButtonSize, height: Layout.secondaryButtonSize)
		}
		.buttonStyle(.bordered)
		.help(title)
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
		HStack(alignment: .center, spacing: 16) {
			metricBadge(
				title: "Supported",
				value: datasetState.supportedFilesText,
				systemImage: "photo.stack",
				helpText: "Supported image files found in the selected dataset."
			)
			metricBadge(
				title: "Analyzed",
				value: datasetState.analyzedPhotosText,
				systemImage: "checkmark.circle",
				helpText: "Photos successfully processed during the current analysis."
			)
			metricBadge(
				title: "Status",
				value: datasetState.analysisStatus.displayText,
				systemImage: "waveform.path.ecg",
				helpText: "Current dataset analysis status."
			)
		}
		.font(.footnote)
		.foregroundStyle(.secondary)
	}

	private func metricBadge(
		title: String,
		value: String,
		systemImage: String,
		helpText: String
	) -> some View {
		Label {
			HStack(spacing: 4) {
				Text(title)
				Text(value)
					.foregroundStyle(.primary)
			}
		} icon: {
			Image(systemName: systemImage)
		}
		.help(helpText)
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
