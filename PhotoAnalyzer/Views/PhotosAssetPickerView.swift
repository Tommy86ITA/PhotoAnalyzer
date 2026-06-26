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
    static let thumbnailSide: CGFloat = 92
    static let thumbnailPixelSide: CGFloat = 184
    static let gridSpacing: CGFloat = 8
}

/// Sheet for selecting individual PhotoKit assets as the active Photos source.
struct PhotosAssetPickerView: View {
    let assets: [PhotosAssetSummary]
    let isLoading: Bool
    let error: AppErrorInfo?
    let selectedAssetIdentifiers: Set<String>
    let toggleAsset: (PhotosAssetSummary) -> Void
    let confirmSelection: () -> Void
    let refresh: () -> Void
    let dismiss: () -> Void

    private var selectedCountText: String {
        let count = selectedAssetIdentifiers.count
        return count == 1 ? "1 selected" : "\(count) selected"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Select Photos")
                        .font(.title2.weight(.semibold))

                    Text(selectedCountText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel", action: dismiss)

                Button("Use Selected", action: confirmSelection)
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedAssetIdentifiers.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }

            Divider()

            content
        }
        .padding(24)
        .frame(width: 760, height: 560, alignment: .topLeading)
        .onAppear(perform: refresh)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Loading Photos...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error {
            VStack(alignment: .leading, spacing: 12) {
                Label(error.userMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)

                Button("Try Again", action: refresh)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if assets.isEmpty {
            ContentUnavailableView(
                "No Photos",
                systemImage: "photo.on.rectangle.angled",
                description: Text("No image assets were found in the Photos Library.")
            )
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(
                                minimum: PhotosAssetPickerLayout.thumbnailSide,
                                maximum: PhotosAssetPickerLayout.thumbnailSide
                            ),
                            spacing: PhotosAssetPickerLayout.gridSpacing
                        )
                    ],
                    spacing: PhotosAssetPickerLayout.gridSpacing
                ) {
                    ForEach(assets) { asset in
                        PhotosAssetThumbnailCell(
                            asset: asset,
                            isSelected: selectedAssetIdentifiers.contains(asset.localIdentifier),
                            toggleSelection: { toggleAsset(asset) }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct PhotosAssetThumbnailCell: View {
    let asset: PhotosAssetSummary
    let isSelected: Bool
    let toggleSelection: () -> Void

    @State private var thumbnail: NSImage?

    var body: some View {
        Button(action: toggleSelection) {
            ZStack(alignment: .topTrailing) {
                thumbnailContent

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .blue)
                        .padding(6)
                }
            }
            .frame(
                width: PhotosAssetPickerLayout.thumbnailSide,
                height: PhotosAssetPickerLayout.thumbnailSide
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 3 : 1)
            }
        }
        .buttonStyle(.plain)
        .task(id: asset.localIdentifier) {
            thumbnail = await PhotosLibraryAssetBrowserService().thumbnail(
                for: asset.localIdentifier,
                targetSize: CGSize(
                    width: PhotosAssetPickerLayout.thumbnailPixelSide,
                    height: PhotosAssetPickerLayout.thumbnailPixelSide
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
                    width: PhotosAssetPickerLayout.thumbnailSide,
                    height: PhotosAssetPickerLayout.thumbnailSide
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
