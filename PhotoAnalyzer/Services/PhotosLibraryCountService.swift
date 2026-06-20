//
//  PhotosLibraryCountService.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 20/06/2026.
//

import Foundation

#if canImport(Photos)
@preconcurrency import Photos
#endif

/// Counts image assets in Photos Library selections without materializing files.
nonisolated struct PhotosLibraryCountService: Sendable {
    func countImageAssets(in selection: PhotosSelection) async throws -> Int {
        #if canImport(Photos)
        try await requestReadAccessIfNeeded()

        switch selection.mode {
        case .assets(let localIdentifiers):
            return PHAsset.fetchAssets(
                withLocalIdentifiers: localIdentifiers,
                options: imageFetchOptions()
            ).count
        case .album(let localIdentifier, _):
            let collections = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [localIdentifier],
                options: nil
            )
            guard let collection = collections.firstObject else {
                throw PhotosLibraryAssetExporterError.albumNotFound(localIdentifier)
            }
            return PHAsset.fetchAssets(in: collection, options: imageFetchOptions()).count
        case .library:
            return PHAsset.fetchAssets(with: imageFetchOptions()).count
        }
        #else
        throw PhotosLibraryAssetExporterError.photosUnavailable
        #endif
    }
}

#if canImport(Photos)
private extension PhotosLibraryCountService {
    nonisolated func requestReadAccessIfNeeded() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            return
        case .notDetermined:
            let requestedStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard requestedStatus == .authorized || requestedStatus == .limited else {
                throw PhotosLibraryAssetExporterError.unauthorized
            }
        case .denied, .restricted:
            throw PhotosLibraryAssetExporterError.unauthorized
        @unknown default:
            throw PhotosLibraryAssetExporterError.unauthorized
        }
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
