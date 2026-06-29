//
//  PhotosSelectionCoordinator.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 28/06/2026.
//

import Foundation
import Observation

/// Observable state and actions for Photos Library pickers.
@MainActor
@Observable
final class PhotosSelectionCoordinator {
    /// Selected PhotoKit asset identifiers used to build a manual Photos Library source.
    var selectedAssetIdentifiers = Set<String>()

    /// Last manually selected PhotoKit asset, used as the anchor for shift-selection.
    var lastSelectedAssetIdentifier: String?

    /// Image assets available for manual PhotoKit-backed Photos selection.
    var assets: [PhotosAssetSummary] = []

    /// Whether Photos assets are currently loading.
    var isLoadingAssets = false

    /// Asset loading error shown in the asset picker sheet.
    var assetLoadingError: AppErrorInfo?

    /// Albums available for PhotoKit-backed Photos selection.
    var albums: [PhotosAlbumSummary] = []

    /// Whether Photos albums are currently loading.
    var isLoadingAlbums = false

    /// Album loading error shown in the album picker sheet.
    var albumLoadingError: AppErrorInfo?

    /// Currently running asset load task, if any.
    @ObservationIgnored private var assetLoadingTask: Task<Void, Never>?

    /// Currently running album load task, if any.
    @ObservationIgnored private var albumLoadingTask: Task<Void, Never>?

    deinit {
        assetLoadingTask?.cancel()
        albumLoadingTask?.cancel()
    }

    /// Clears manual Photos asset selection state.
    func resetSelection() {
        selectedAssetIdentifiers = []
        lastSelectedAssetIdentifier = nil
    }

    /// Loads PhotoKit assets for the manual Photos picker sheet.
    func loadAssets() {
        guard !isLoadingAssets else {
            return
        }

        isLoadingAssets = true
        assetLoadingError = nil
        assetLoadingTask?.cancel()

        let task = Task { [weak self] in
            defer {
                self?.isLoadingAssets = false
                self?.assetLoadingTask = nil
            }

            do {
                let assets = try await PhotosLibraryAssetBrowserService().fetchImageAssets()
                guard let self, !Task.isCancelled else {
                    return
                }

                self.assets = assets
                assetLoadingError = nil
            } catch {
                guard let self, !Task.isCancelled else {
                    return
                }

                assets = []
                assetLoadingError = AppErrorInfo.exportFailure(error)
            }
        }
        assetLoadingTask = task
    }

    /// Toggles a PhotoKit asset in the manual Photos selection sheet.
    func toggleAsset(
        _ asset: PhotosAssetSummary,
        in orderedAssets: [PhotosAssetSummary],
        isCommandSelection: Bool,
        isRangeSelection: Bool
    ) {
        if isRangeSelection {
            selectAssetRange(
                through: asset,
                in: orderedAssets,
                extendsExistingSelection: isCommandSelection
            )
        } else if isCommandSelection {
            toggleAsset(asset)
        } else {
            selectedAssetIdentifiers = [asset.localIdentifier]
            lastSelectedAssetIdentifier = asset.localIdentifier
        }
    }

    /// Selects the provided PhotoKit assets in the manual Photos selection sheet.
    func selectAssets(_ assets: [PhotosAssetSummary]) {
        selectedAssetIdentifiers = Set(assets.map(\.localIdentifier))
        lastSelectedAssetIdentifier = assets.last?.localIdentifier
    }

    /// Clears the manual PhotoKit asset selection.
    func clearSelectedAssets() {
        resetSelection()
    }

    /// Returns manually selected asset identifiers in current picker order.
    func orderedSelectedAssetIdentifiers() -> [String]? {
        guard !selectedAssetIdentifiers.isEmpty else {
            return nil
        }

        return assets
            .map(\.localIdentifier)
            .filter { selectedAssetIdentifiers.contains($0) }
    }

    /// Loads PhotoKit albums for the album picker sheet.
    func loadAlbums() {
        guard !isLoadingAlbums else {
            return
        }

        isLoadingAlbums = true
        albumLoadingError = nil
        albumLoadingTask?.cancel()

        let task = Task { [weak self] in
            defer {
                self?.isLoadingAlbums = false
                self?.albumLoadingTask = nil
            }

            do {
                let albums = try await PhotosLibraryAlbumService().fetchAlbums()
                guard let self, !Task.isCancelled else {
                    return
                }

                self.albums = albums
                albumLoadingError = nil
            } catch {
                guard let self, !Task.isCancelled else {
                    return
                }

                albums = []
                albumLoadingError = AppErrorInfo.exportFailure(error)
            }
        }
        albumLoadingTask = task
    }

    /// Toggles an asset while preserving the rest of the selection.
    private func toggleAsset(_ asset: PhotosAssetSummary) {
        if selectedAssetIdentifiers.contains(asset.localIdentifier) {
            selectedAssetIdentifiers.remove(asset.localIdentifier)
        } else {
            selectedAssetIdentifiers.insert(asset.localIdentifier)
            lastSelectedAssetIdentifier = asset.localIdentifier
        }
    }

    /// Selects a contiguous range from the last selected asset to the current asset.
    private func selectAssetRange(
        through asset: PhotosAssetSummary,
        in orderedAssets: [PhotosAssetSummary],
        extendsExistingSelection: Bool
    ) {
        guard let anchorIdentifier = lastSelectedAssetIdentifier,
              let anchorIndex = orderedAssets.firstIndex(where: { $0.localIdentifier == anchorIdentifier }),
              let currentIndex = orderedAssets.firstIndex(of: asset) else {
            selectedAssetIdentifiers = [asset.localIdentifier]
            lastSelectedAssetIdentifier = asset.localIdentifier
            return
        }

        let bounds = min(anchorIndex, currentIndex)...max(anchorIndex, currentIndex)
        let rangeIdentifiers = Set(orderedAssets[bounds].map(\.localIdentifier))

        if extendsExistingSelection {
            selectedAssetIdentifiers.formUnion(rangeIdentifiers)
        } else {
            selectedAssetIdentifiers = rangeIdentifiers
        }
    }
}
