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

#if canImport(CoreLocation)
import CoreLocation
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

        let fetchOptions = imageFetchOptions()

        return await Task.detached(priority: .userInitiated) {
            let result = PHAsset.fetchAssets(with: fetchOptions)
            var assets: [PhotosAssetSummary] = []
            assets.reserveCapacity(result.count)

            result.enumerateObjects { asset, _, _ in
                assets.append(PhotosAssetSummary(
                    localIdentifier: asset.localIdentifier,
                    creationDate: asset.creationDate,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    latitude: asset.location?.coordinate.latitude,
                    longitude: asset.location?.coordinate.longitude,
                    searchText: Self.searchText(
                        creationDate: asset.creationDate,
                        pixelWidth: asset.pixelWidth,
                        pixelHeight: asset.pixelHeight
                    )
                ))
            }

            return assets
        }.value
        #else
        throw PhotosLibraryAssetExporterError.photosUnavailable
        #endif
    }

    #if canImport(AppKit)
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

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false
        options.version = .current

        return await PHCachingImageManager.default().requestFinalImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        )
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

    nonisolated static func searchText(
        creationDate: Date?,
        pixelWidth: Int,
        pixelHeight: Int
    ) -> String {
        var tokens = [
            "\(pixelWidth)x\(pixelHeight)",
            "\(pixelWidth)",
            "\(pixelHeight)"
        ].compactMap { $0 }

        if let creationDate {
            tokens.append(contentsOf: dateSearchTokens(for: creationDate))
        }

        return tokens
            .joined(separator: " ")
            .lowercased()
    }

    nonisolated static func dateSearchTokens(for date: Date) -> [String] {
        let numericFormatter = DateFormatter()
        numericFormatter.dateStyle = .short
        numericFormatter.timeStyle = .none

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"

        let year = Calendar.current.component(.year, from: date)

        return [
            numericFormatter.string(from: date),
            monthFormatter.string(from: date),
            String(year)
        ]
    }
}

#if canImport(AppKit)
private extension PHImageManager {
    func requestFinalImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        options: PHImageRequestOptions?
    ) async -> NSImage? {
        await withCheckedContinuation { continuation in
            let didResume = LockedFlag()

            requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, info in
                if info?[PHImageErrorKey] != nil || info?[PHImageCancelledKey] != nil {
                    if didResume.setIfUnset() {
                        continuation.resume(returning: nil)
                    }
                    return
                }

                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                    return
                }

                if didResume.setIfUnset() {
                    continuation.resume(returning: image)
                }
            }
        }
    }
}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var isSet = false

    func setIfUnset() -> Bool {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard !isSet else {
            return false
        }

        isSet = true
        return true
    }
}
#endif
#endif
