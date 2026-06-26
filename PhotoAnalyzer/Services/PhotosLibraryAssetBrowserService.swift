//
//  PhotosLibraryAssetBrowserService.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 26/06/2026.
//

import Foundation

#if canImport(AppKit)
import AppKit
#endif

#if canImport(Photos)
@preconcurrency import Photos
#endif

/// Fetches PhotoKit image assets and thumbnails for the custom Photos selector.
nonisolated struct PhotosLibraryAssetBrowserService: Sendable {
    private let authorizationService: PhotosLibraryAuthorizationService

    init(authorizationService: PhotosLibraryAuthorizationService = PhotosLibraryAuthorizationService()) {
        self.authorizationService = authorizationService
    }

    func fetchImageAssets() async throws -> [PhotosAssetSummary] {
        #if canImport(Photos)
        try await authorizationService.requestReadAccessIfNeeded()

        let result = PHAsset.fetchAssets(with: imageFetchOptions())
        var assets: [PhotosAssetSummary] = []
        assets.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            assets.append(PhotosAssetSummary(
                localIdentifier: asset.localIdentifier,
                creationDate: asset.creationDate
            ))
        }

        return assets
        #else
        throw PhotosLibraryAssetExporterError.photosUnavailable
        #endif
    }

    #if canImport(AppKit)
    @MainActor
    func thumbnail(
        for localIdentifier: String,
        targetSize: CGSize
    ) async -> NSImage? {
        #if canImport(Photos)
        let result = PHAsset.fetchAssets(
            withLocalIdentifiers: [localIdentifier],
            options: nil
        )
        guard let asset = result.firstObject else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false
            options.isSynchronous = false

            PHCachingImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
        #else
        return nil
        #endif
    }
    #endif
}

#if canImport(Photos)
private extension PhotosLibraryAssetBrowserService {
    nonisolated func imageFetchOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        options.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared]
        options.predicate = NSPredicate(
            format: "mediaType == %d",
            PHAssetMediaType.image.rawValue
        )
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        return options
    }
}
#endif
