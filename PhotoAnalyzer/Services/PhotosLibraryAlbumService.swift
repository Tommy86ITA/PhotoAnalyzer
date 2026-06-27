//
//  PhotosLibraryAlbumService.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 26/06/2026.
//

import Foundation

#if canImport(Photos)
@preconcurrency import Photos
#endif

/// Fetches user-visible Photos albums with image counts.
nonisolated struct PhotosLibraryAlbumService: Sendable {
    private let authorizationService: PhotosLibraryAuthorizationService

    init(authorizationService: PhotosLibraryAuthorizationService = PhotosLibraryAuthorizationService()) {
        self.authorizationService = authorizationService
    }

    func fetchAlbums() async throws -> [PhotosAlbumSummary] {
        #if canImport(Photos)
        try await authorizationService.requestReadAccessIfNeeded()

        var albums: [PhotosAlbumSummary] = []
        albums.append(contentsOf: userAlbums())
        albums.append(contentsOf: smartAlbums())

        return albums
            .filter { $0.imageAssetCount > 0 }
            .sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        #else
        throw PhotosLibraryAssetExporterError.photosUnavailable
        #endif
    }
}

#if canImport(Photos)
private extension PhotosLibraryAlbumService {
    nonisolated func userAlbums() -> [PhotosAlbumSummary] {
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: nil
        )
        return summaries(from: collections)
    }

    nonisolated func smartAlbums() -> [PhotosAlbumSummary] {
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .any,
            options: nil
        )
        return summaries(from: collections)
    }

    nonisolated func summaries(from collections: PHFetchResult<PHAssetCollection>) -> [PhotosAlbumSummary] {
        var summaries: [PhotosAlbumSummary] = []
        summaries.reserveCapacity(collections.count)

        collections.enumerateObjects { collection, _, _ in
            let count = PHAsset.fetchAssets(in: collection, options: imageFetchOptions()).count
            guard count > 0 else {
                return
            }

            summaries.append(PhotosAlbumSummary(
                localIdentifier: collection.localIdentifier,
                title: collection.localizedTitle ?? "Untitled Album",
                imageAssetCount: count
            ))
        }

        return summaries
    }

    nonisolated func imageFetchOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        options.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared]
        options.predicate = NSPredicate(
            format: "mediaType == %d",
            PHAssetMediaType.image.rawValue
        )
        return options
    }
}
#endif
