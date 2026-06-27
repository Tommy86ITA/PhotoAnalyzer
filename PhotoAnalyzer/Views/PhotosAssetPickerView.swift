//
//  PhotosAssetPickerView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 26/06/2026.
//

import SwiftUI

#if canImport(MapKit)
import MapKit
#endif

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
    @State private var placeSearchResult: PhotosPlaceSearchResult?
    @State private var placeSearchError: String?
    @State private var isSearchingPlace = false

    #if canImport(MapKit)
    @State private var mapPosition: MapCameraPosition = .automatic
    #endif

    @AppStorage("photos.assetPicker.thumbnailSide") private var thumbnailSide = PhotosAssetPickerLayout.defaultThumbnailSide

    private let placeSearchService = PhotosPlaceSearchService()

    private var thumbnailPixelSide: CGFloat {
        CGFloat(thumbnailSide * PhotosAssetPickerLayout.thumbnailScale)
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredAssets: [PhotosAssetSummary] {
        let query = trimmedSearchText

        let textFilteredAssets = assets.filter { asset in
            query.isEmpty || asset.searchText.localizedCaseInsensitiveContains(query)
        }

        #if canImport(CoreLocation)
        if let placeSearchResult {
            return textFilteredAssets.filter { asset in
                asset.isWithin(placeSearchResult)
            }
        }
        #endif

        return textFilteredAssets
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

            if placeSearchResult != nil || !searchText.isEmpty {
                Button("Clear Filters") {
                    clearFilters()
                }
                .help("Clear text and place filters")
            }

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

            Button {
                searchPlace()
            } label: {
                if isSearchingPlace {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "mappin.and.ellipse")
                }
            }
            .buttonStyle(.plain)
            .disabled(trimmedSearchText.isEmpty || isSearchingPlace)
            .help("Search this text as a place")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(width: 260)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .help("Search by date, year, month, dimensions, or use the pin to filter by place")
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

    private func clearFilters() {
        searchText = ""
        placeSearchResult = nil
        placeSearchError = nil

        #if canImport(MapKit)
        mapPosition = .automatic
        #endif
    }

    private func searchPlace() {
        let query = trimmedSearchText
        guard !query.isEmpty else {
            return
        }

        isSearchingPlace = true
        placeSearchError = nil

        Task {
            do {
                let result = try await placeSearchService.search(query: query)
                await MainActor.run {
                    placeSearchResult = result
                    searchText = ""
                    isSearchingPlace = false
                    updateMapPosition(for: result)
                }
            } catch {
                await MainActor.run {
                    placeSearchResult = nil
                    placeSearchError = error.localizedDescription
                    isSearchingPlace = false
                }
            }
        }
    }

    private func updateMapPosition(for result: PhotosPlaceSearchResult) {
        #if canImport(MapKit)
        let radiusDegrees = max(result.radiusMeters / 111_000, 0.2)
        mapPosition = .region(MKCoordinateRegion(
            center: result.coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: radiusDegrees * 2,
                longitudeDelta: radiusDegrees * 2
            )
        ))
        #endif
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
            VStack(spacing: 0) {
                placeSearchPanel

                ContentUnavailableView(
                    "No Matching Photos",
                    systemImage: "magnifyingglass",
                    description: Text("No photos match the current filters.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            VStack(spacing: 0) {
                placeSearchPanel

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

    @ViewBuilder
    private var placeSearchPanel: some View {
        if let placeSearchResult {
            HStack(spacing: 12) {
                #if canImport(MapKit)
                Map(position: $mapPosition, interactionModes: [.pan, .zoom]) {
                    MapCircle(center: placeSearchResult.coordinate, radius: placeSearchResult.radiusMeters)
                        .foregroundStyle(.blue.opacity(0.12))
                        .stroke(.blue.opacity(0.35), lineWidth: 1)

                    Marker(placeSearchResult.displayName, coordinate: placeSearchResult.coordinate)
                }
                .mapStyle(.standard(elevation: .flat))
                .frame(width: 180, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.secondary.opacity(0.2), lineWidth: 1)
                }
                #endif

                VStack(alignment: .leading, spacing: 4) {
                    Label(placeSearchResult.displayName, systemImage: "mappin.and.ellipse")
                        .font(.headline)

                    Text("\(filteredAssets.count) photos within \(Int(placeSearchResult.radiusMeters / 1_000)) km")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                Button {
                    self.placeSearchResult = nil

                    #if canImport(MapKit)
                    mapPosition = .automatic
                    #endif
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear place filter")
            }
            .padding(.horizontal, PhotosAssetPickerLayout.horizontalPadding)
            .padding(.vertical, 10)
            .background(.quaternary.opacity(0.35))
        } else if let placeSearchError {
            HStack(spacing: 8) {
                Label(placeSearchError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button {
                    self.placeSearchError = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Dismiss place search error")
            }
            .font(.subheadline)
            .padding(.horizontal, PhotosAssetPickerLayout.horizontalPadding)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.35))
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
