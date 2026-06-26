//
//  PhotosAssetPickerView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 26/06/2026.
//

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

private enum PhotosAssetPickerLayout {
    static let defaultThumbnailSide = 92.0
    static let minimumThumbnailSide = 72.0
    static let maximumThumbnailSide = 140.0
    static let thumbnailStep = 8.0
    static let thumbnailScale = 3.0
    static let gridSpacing: CGFloat = 10
    static let horizontalPadding: CGFloat = 24
    static let verticalPadding: CGFloat = 18
}

/// Sheet for selecting individual PhotoKit assets as the active Photos source.
struct PhotosAssetPickerView: View {
    let assets: [PhotosAssetSummary]
    let isLoading: Bool
    let error: AppErrorInfo?
    let selectedAssetIdentifiers: Set<String>
    let toggleAsset: (PhotosAssetSummary, [PhotosAssetSummary]) -> Void
    let selectAssets: ([PhotosAssetSummary]) -> Void
    let clearSelection: () -> Void
    let confirmSelection: () -> Void
    let refresh: () -> Void
    let dismiss: () -> Void

    @State private var searchText = ""
    @AppStorage("photos.assetPicker.thumbnailSide") private var thumbnailSide = PhotosAssetPickerLayout.defaultThumbnailSide

    private var thumbnailPixelSide: CGFloat {
        CGFloat(thumbnailSide * PhotosAssetPickerLayout.thumbnailScale)
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredAssets: [PhotosAssetSummary] {
        let query = trimmedSearchText
        guard !query.isEmpty else {
            return assets
        }

        return assets.filter { asset in
            asset.searchText.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedCountText: String {
        let count = selectedAssetIdentifiers.count
        return count == 1 ? "1 selected" : "\(count) selected"
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            footer
        }
        .frame(width: 820, height: 600, alignment: .topLeading)
        .onAppear {
            normalizePersistedThumbnailSide()
            refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Select Photos")
                    .font(.title2.weight(.semibold))

                Text(selectedCountText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)

            searchField

            thumbnailSizeControl
        }
        .padding(.horizontal, PhotosAssetPickerLayout.horizontalPadding)
        .padding(.vertical, PhotosAssetPickerLayout.verticalPadding)
    }

    private var footer: some View {
        HStack {
            Button("Select All") {
                selectAssets(filteredAssets)
            }
                .disabled(filteredAssets.isEmpty)
                .keyboardShortcut("a", modifiers: .command)
                .help("Select all visible photos")

            Button("Clear Selection", action: clearSelection)
                .disabled(selectedAssetIdentifiers.isEmpty)
                .help("Clear selected photos")

            Spacer(minLength: 0)

            Button("Cancel", action: dismiss)
                .keyboardShortcut(.cancelAction)
                .help("Close without changing the Photos selection")

            Button("Use Selected", action: confirmSelection)
                .buttonStyle(.borderedProminent)
                .disabled(selectedAssetIdentifiers.isEmpty)
                .keyboardShortcut(.defaultAction)
                .help(selectedAssetIdentifiers.isEmpty ? "Select one or more photos first" : "Use the selected photos as the source")
        }
        .padding(.horizontal, PhotosAssetPickerLayout.horizontalPadding)
        .padding(.vertical, 14)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear Search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(width: 220)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .help("Search by filename, date, year, month, or image dimensions")
    }

    private var thumbnailSizeControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)

            Slider(
                value: $thumbnailSide,
                in: PhotosAssetPickerLayout.minimumThumbnailSide...PhotosAssetPickerLayout.maximumThumbnailSide,
                step: PhotosAssetPickerLayout.thumbnailStep
            )
            .frame(width: 150)

            Image(systemName: "photo.fill")
                .foregroundStyle(.secondary)
        }
        .help("Thumbnail size")
    }

    private func normalizePersistedThumbnailSide() {
        thumbnailSide = min(
            PhotosAssetPickerLayout.maximumThumbnailSide,
            max(PhotosAssetPickerLayout.minimumThumbnailSide, thumbnailSide)
        )
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Loading Photos...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error {
            VStack(spacing: 12) {
                Label(error.userMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Try Again", action: refresh)
                    .help("Reload Photos")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if assets.isEmpty {
            ContentUnavailableView(
                "No Photos",
                systemImage: "photo.on.rectangle.angled",
                description: Text("No image assets were found in the Photos Library.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredAssets.isEmpty {
            ContentUnavailableView(
                "No Matching Photos",
                systemImage: "magnifyingglass",
                description: Text("No photos match the current search.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(
                                minimum: CGFloat(thumbnailSide),
                                maximum: CGFloat(thumbnailSide)
                            ),
                            spacing: PhotosAssetPickerLayout.gridSpacing
                        )
                    ],
                    spacing: PhotosAssetPickerLayout.gridSpacing
                ) {
                    ForEach(filteredAssets) { asset in
                        PhotosAssetThumbnailCell(
                            asset: asset,
                            thumbnailSide: CGFloat(thumbnailSide),
                            thumbnailPixelSide: thumbnailPixelSide,
                            isSelected: selectedAssetIdentifiers.contains(asset.localIdentifier),
                            toggleSelection: { toggleAsset(asset, filteredAssets) }
                        )
                    }
                }
                .padding(PhotosAssetPickerLayout.gridSpacing)
            }
        }
    }
}

private struct PhotosAssetThumbnailCell: View {
    let asset: PhotosAssetSummary
    let thumbnailSide: CGFloat
    let thumbnailPixelSide: CGFloat
    let isSelected: Bool
    let toggleSelection: () -> Void

    @State private var thumbnail: NSImage?

    var body: some View {
        Button(action: toggleSelection) {
            ZStack(alignment: .topTrailing) {
                thumbnailContent

                if isSelected {
                    Color.accentColor
                        .opacity(0.18)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .blue)
                        .padding(6)
                }
            }
            .frame(
                width: thumbnailSide,
                height: thumbnailSide
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .help("Click to select. Command-click toggles one photo. Shift-click selects a range.")
        .task(id: "\(asset.localIdentifier)-\(Int(thumbnailPixelSide))") {
            thumbnail = await PhotosLibraryAssetBrowserService().thumbnail(
                for: asset.localIdentifier,
                targetSize: CGSize(
                    width: thumbnailPixelSide,
                    height: thumbnailPixelSide
                )
            )
        }
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(
                    width: thumbnailSide,
                    height: thumbnailSide
                )
                .clipped()
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }
}
