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
		static let actionColumnWidth: CGFloat = 284
		static let secondaryButtonSpacing: CGFloat = 6
		static let secondaryButtonHeight: CGFloat = 44
		static let infoIconWidth: CGFloat = 18
		static let infoColumnSpacing: CGFloat = 10
		static let infoTitleWidth: CGFloat = 86

		static var secondaryButtonWidth: CGFloat {
			(actionColumnWidth - (secondaryButtonSpacing * 2)) / 3
		}

		static var infoTitleLeadingPadding: CGFloat {
			infoIconWidth + infoColumnSpacing
		}

		static var infoValueLeadingPadding: CGFloat {
			infoTitleLeadingPadding + infoTitleWidth + infoColumnSpacing
		}
	}

	let datasetState: DatasetUIState
	let sourceIconName: String
	let sourceText: String
	let sourcePath: String?
	let isSourcePlaceholder: Bool
	let isFolderSource: Bool
	let canAnalyze: Bool
	let isAnalyzing: Bool
	let isCountingSupportedFiles: Bool
	let useUnmodifiedPhotosOriginals: Bool
	let downloadMissingPhotosOriginals: Bool
	@Binding var includeSubfolders: Bool
	let selectFolder: () -> Void
	let selectPhotos: () -> Void
	let choosePhotosAlbum: () -> Void
	let useEntirePhotosLibrary: () -> Void
	let openSettings: () -> Void
	let analyze: () -> Void
	let cancelAnalysis: () -> Void

	var body: some View {
		GroupBox("Dataset") {
			VStack(alignment: .leading, spacing: 10) {
				HStack(alignment: .top, spacing: 18) {
					VStack(alignment: .leading, spacing: 8) {
						sourceDetails
					}
					.frame(maxWidth: .infinity, alignment: .leading)

					VStack(alignment: .trailing, spacing: 10) {
						secondaryActions

						analysisButton
							.frame(width: Layout.actionColumnWidth)
					}
					.frame(width: Layout.actionColumnWidth, alignment: .trailing)
				}

				Divider()

				metricsRow
			}
			.padding(.vertical, 2)
		}
	}

	@ViewBuilder
	private var sourceDetails: some View {
		if isSourcePlaceholder {
			infoRow(
				iconName: sourceIconName,
				title: "Source",
				text: sourceText,
				isPlaceholder: true
			)
		} else if isFolderSource {
			infoRow(
				iconName: "folder.fill",
				title: "Source",
				text: "Folder"
			)

			infoRow(
				iconName: "folder",
				title: "Folder path",
				text: sourcePath ?? sourceText,
				path: sourcePath,
				usesMonospacedText: true
			)

			Toggle("Include subfolders", isOn: $includeSubfolders)
				.disabled(isAnalyzing || isCountingSupportedFiles)
				.controlSize(.small)
				.padding(.leading, Layout.infoValueLeadingPadding)
		} else {
			infoRow(
				iconName: "photo.on.rectangle.angled",
				title: "Source",
				text: "Photos Library"
			)

			infoRow(
				iconName: "checkmark.circle",
				title: "Selected files",
				text: datasetState.supportedFilesText
			)

			photosOptionsRow
		}
	}

	private var photosOptionsRow: some View {
		HStack(alignment: .firstTextBaseline, spacing: Layout.infoColumnSpacing) {
			Image(systemName: "slider.horizontal.3")
				.foregroundStyle(.secondary)
				.frame(width: Layout.infoIconWidth)

			Text("Options")
				.font(.footnote.weight(.semibold))
				.foregroundStyle(.secondary)
				.frame(width: Layout.infoTitleWidth, alignment: .leading)

			photosSettingsIndicators
		}
	}

	private var photosSettingsIndicators: some View {
		HStack(spacing: 12) {
			Label(
				useUnmodifiedPhotosOriginals ? "Originals" : "Current version",
				systemImage: useUnmodifiedPhotosOriginals ? "photo.badge.checkmark" : "photo"
			)
			.help(useUnmodifiedPhotosOriginals ? "Using unmodified originals" : "Using current Photos versions")

			Label(
				downloadMissingPhotosOriginals ? "iCloud downloads" : "Local only",
				systemImage: downloadMissingPhotosOriginals ? "icloud.and.arrow.down" : "icloud.slash"
			)
				.foregroundStyle(downloadMissingPhotosOriginals ? .blue : .secondary)
				.help(downloadMissingPhotosOriginals ? "iCloud downloads enabled" : "iCloud downloads disabled")
		}
		.font(.footnote)
		.foregroundStyle(.secondary)
	}

	private var secondaryActions: some View {
		HStack(spacing: Layout.secondaryButtonSpacing) {
			compactButton(
				title: "Select Folder",
				systemImage: "folder.badge.plus",
				action: selectFolder
			)
			.disabled(isAnalyzing || isCountingSupportedFiles)

			Menu {
				Button(action: selectPhotos) {
					Label("Select Photos...", systemImage: "photo.on.rectangle.angled")
				}

				Button(action: choosePhotosAlbum) {
					Label("Choose Album...", systemImage: "photo.stack")
				}

				Button(action: useEntirePhotosLibrary) {
					Label("Use Entire Library", systemImage: "photo.on.rectangle")
				}
			} label: {
				Label("Select Photos", systemImage: "photo.on.rectangle.angled")
					.labelStyle(.iconOnly)
					.frame(maxWidth: .infinity, minHeight: Layout.secondaryButtonHeight)
			}
			.menuStyle(.button)
			.buttonStyle(.bordered)
			.frame(width: Layout.secondaryButtonWidth)
			.disabled(isAnalyzing || isCountingSupportedFiles)
			.help("Choose Photos source")

			compactButton(
				title: "Settings",
				systemImage: "gearshape",
				action: openSettings
			)
		}
		.frame(width: Layout.actionColumnWidth)
	}

	private func compactButton(
		title: String,
		systemImage: String,
		action: @escaping () -> Void
	) -> some View {
		Button(action: action) {
			Label(title, systemImage: systemImage)
				.labelStyle(.iconOnly)
				.frame(maxWidth: .infinity, minHeight: Layout.secondaryButtonHeight)
		}
		.buttonStyle(.bordered)
		.frame(width: Layout.secondaryButtonWidth)
		.help(title)
	}

	private func infoRow(
		iconName: String,
		title: String,
		text: String,
		path: String? = nil,
		isPlaceholder: Bool = false,
		usesMonospacedText: Bool = false
	) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: Layout.infoColumnSpacing) {
			Image(systemName: iconName)
				.foregroundStyle(.secondary)
				.frame(width: Layout.infoIconWidth)

			Text(title)
				.font(.footnote.weight(.semibold))
				.foregroundStyle(.secondary)
				.frame(width: Layout.infoTitleWidth, alignment: .leading)

			Text(text)
				.font(usesMonospacedText ? .system(.body, design: .monospaced) : .body)
				.foregroundStyle(isPlaceholder ? .secondary : .primary)
				.lineLimit(1)
				.truncationMode(.middle)
				.textSelection(.enabled)
				.help(path ?? text)

			if path != nil {
				CopyPathButton(path: path)
			}
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
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.borderedProminent)
			.tint(.red)
			.frame(maxWidth: .infinity)
		} else {
			Button(action: analyze) {
				Label("Analyze & Generate AI Package", systemImage: "shippingbox")
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.borderedProminent)
			.disabled(!canAnalyze || isCountingSupportedFiles)
			.frame(maxWidth: .infinity)
		}
	}
}
