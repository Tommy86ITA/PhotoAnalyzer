//
//  PhotosLibraryAssetExporter.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Foundation

#if canImport(Photos)
@preconcurrency import Photos
#endif

/// A Photos asset materialized into the temporary file workspace.
nonisolated struct MaterializedPhotosAsset: Sendable {
    let assetLocalIdentifier: String
    let originalFilename: String?
    let fileURL: URL
    let representation: PhotosAssetRepresentation
    let metadataCacheSourceKey: MetadataCacheSourceKey

    var displayInfo: SourceFileDisplayInfo {
        SourceFileDisplayInfo(
            fileName: originalFilename ?? fileURL.lastPathComponent,
            sourceFile: "photos://asset/\(encodedAssetIdentifier)"
        )
    }

    private var encodedAssetIdentifier: String {
        var allowedCharacters = CharacterSet.urlPathAllowed
        allowedCharacters.remove(charactersIn: "/")
        return assetLocalIdentifier.addingPercentEncoding(withAllowedCharacters: allowedCharacters)
            ?? assetLocalIdentifier
    }
}

/// Result of exporting a Photos selection to physical files.
nonisolated struct PhotosMaterializationResult: Sendable {
    let assets: [MaterializedPhotosAsset]
    let skippedAssets: [PhotosAssetExportFailure]
    let workspace: TemporaryAssetWorkspace

    var fileURLs: [URL] {
        assets.map(\.fileURL)
    }

    var displayInfoByFileURL: [URL: SourceFileDisplayInfo] {
        Dictionary(uniqueKeysWithValues: assets.map { ($0.fileURL, $0.displayInfo) })
    }

    var metadataCacheSourceKeyByFileURL: [URL: MetadataCacheSourceKey] {
        Dictionary(uniqueKeysWithValues: assets.map { ($0.fileURL, $0.metadataCacheSourceKey) })
    }
}

/// Per-asset export failure, kept separate so partial Photos selections can still be analyzed.
nonisolated struct PhotosAssetExportFailure: Equatable, Sendable {
    let assetLocalIdentifier: String
    let reason: String
}

/// Export limits used to avoid accidental whole-library materialization without confirmation.
nonisolated struct PhotosLibraryExportOptions: Equatable, Sendable {
    let maximumAssetCount: Int?

    init(maximumAssetCount: Int? = nil) {
        self.maximumAssetCount = maximumAssetCount
    }

    static let unrestricted = PhotosLibraryExportOptions()
}

/// Progress emitted while Photos assets are exported into the temporary workspace.
typealias PhotosMaterializationProgressHandler = @Sendable (ProgressSnapshot) -> Void

/// Errors produced while preparing Photos Library assets for file-based analysis.
nonisolated enum PhotosLibraryAssetExporterError: LocalizedError, Equatable {
    case photosUnavailable
    case unauthorized
    case unsupportedSelection
    case albumNotFound(String)
    case assetLimitExceeded(count: Int, limit: Int)
    case noExportableAssets

    var errorDescription: String? {
        switch self {
        case .photosUnavailable:
            "Photos Library access is not available on this platform."
        case .unauthorized:
            "PhotoAnalyzer is not authorized to access the Photos Library."
        case .unsupportedSelection:
            "This Photos Library selection is not supported yet."
        case .albumNotFound(let localIdentifier):
            "Photos album was not found: \(localIdentifier)"
        case .assetLimitExceeded(let count, let limit):
            "Photos selection contains \(count) assets, exceeding the configured limit of \(limit)."
        case .noExportableAssets:
            "No selected Photos assets could be exported for analysis."
        }
    }
}

/// Materializes Photos Library assets into a temporary workspace for ExifTool-based analysis.
final class PhotosLibraryAssetExporter {
    private let workspaceFactory: @Sendable () throws -> TemporaryAssetWorkspace

    init(workspaceFactory: @escaping @Sendable () throws -> TemporaryAssetWorkspace = {
        try TemporaryAssetWorkspace()
    }) {
        self.workspaceFactory = workspaceFactory
    }

    func export(selection: PhotosSelection) async throws -> PhotosMaterializationResult {
        try await export(
            selection: selection,
            options: .unrestricted,
            progressHandler: nil
        )
    }

    func export(
        selection: PhotosSelection,
        options: PhotosLibraryExportOptions = .unrestricted,
        progressHandler: PhotosMaterializationProgressHandler?
    ) async throws -> PhotosMaterializationResult {
        #if canImport(Photos)
        try await requestReadAccessIfNeeded()

        let workspaceFactory = workspaceFactory
        return try await Self.runCancellableDetached {
            let assets = try Self.fetchAssets(for: selection.mode)
            return try await Self.exportAuthorizedAssets(
                assets,
                selection: selection,
                options: options,
                workspaceFactory: workspaceFactory,
                progressHandler: progressHandler
            )
        }
        #else
        throw PhotosLibraryAssetExporterError.photosUnavailable
        #endif
    }
}

private extension PhotosLibraryAssetExporter {
    static func emitProgress(
        completedAssetCount: Int,
        totalAssetCount: Int,
        message: String,
        progressHandler: PhotosMaterializationProgressHandler?
    ) {
        progressHandler?(
            ProgressSnapshot(
                completedUnitCount: Int64(completedAssetCount),
                totalUnitCount: Int64(max(1, totalAssetCount)),
                message: message
            )
        )
    }
}

#if canImport(Photos)
private extension PhotosLibraryAssetExporter {
    static func exportAuthorizedAssets(
        _ assets: [PHAsset],
        selection: PhotosSelection,
        options: PhotosLibraryExportOptions,
        workspaceFactory: @Sendable () throws -> TemporaryAssetWorkspace,
        progressHandler: PhotosMaterializationProgressHandler?
    ) async throws -> PhotosMaterializationResult {
        if let maximumAssetCount = options.maximumAssetCount,
           assets.count > maximumAssetCount {
            throw PhotosLibraryAssetExporterError.assetLimitExceeded(
                count: assets.count,
                limit: maximumAssetCount
            )
        }

        let workspace = try workspaceFactory()
        var exportedAssets: [MaterializedPhotosAsset] = []
        var skippedAssets: [PhotosAssetExportFailure] = []
        exportedAssets.reserveCapacity(assets.count)

        emitProgress(
            completedAssetCount: 0,
            totalAssetCount: assets.count,
            message: "Preparing Photos assets...",
            progressHandler: progressHandler
        )

        for (index, asset) in assets.enumerated() {
            try Task.checkCancellation()

            let localIdentifier = asset.localIdentifier
            let completedAssetCount = index + 1

            guard asset.mediaType == .image else {
                skippedAssets.append(PhotosAssetExportFailure(
                    assetLocalIdentifier: localIdentifier,
                    reason: "Only image assets are supported."
                ))
                emitProgress(
                    completedAssetCount: completedAssetCount,
                    totalAssetCount: assets.count,
                    message: "Preparing Photos assets...",
                    progressHandler: progressHandler
                )
                continue
            }

            guard let resource = Self.resource(for: asset, representation: selection.representation) else {
                skippedAssets.append(PhotosAssetExportFailure(
                    assetLocalIdentifier: localIdentifier,
                    reason: "No exportable image resource was found."
                ))
                emitProgress(
                    completedAssetCount: completedAssetCount,
                    totalAssetCount: assets.count,
                    message: "Preparing Photos assets...",
                    progressHandler: progressHandler
                )
                continue
            }

            let destinationURL = workspace.fileURL(
                preferredFilename: resource.originalFilename,
                fallbackBasename: Self.stableFallbackName(for: localIdentifier)
            )

            do {
                try await Self.write(
                    resource,
                    to: destinationURL,
                    allowsNetworkAccess: selection.networkAccessPolicy.allowsNetworkAccess
                )
                exportedAssets.append(MaterializedPhotosAsset(
                    assetLocalIdentifier: localIdentifier,
                    originalFilename: resource.originalFilename,
                    fileURL: destinationURL,
                    representation: selection.representation,
                    metadataCacheSourceKey: .photosAsset(
                        localIdentifier: localIdentifier,
                        representation: selection.representation,
                        modificationDate: asset.modificationDate
                    )
                ))
            } catch {
                try? FileManager.default.removeItem(at: destinationURL)
                skippedAssets.append(PhotosAssetExportFailure(
                    assetLocalIdentifier: localIdentifier,
                    reason: Self.exportFailureReason(for: error)
                ))
            }

            emitProgress(
                completedAssetCount: completedAssetCount,
                totalAssetCount: assets.count,
                message: "Preparing Photos assets...",
                progressHandler: progressHandler
            )
        }

        guard !exportedAssets.isEmpty else {
            workspace.cleanup()
            throw PhotosLibraryAssetExporterError.noExportableAssets
        }

        return PhotosMaterializationResult(
            assets: exportedAssets,
            skippedAssets: skippedAssets,
            workspace: workspace
        )
    }

    func requestReadAccessIfNeeded() async throws {
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

    static func fetchAssets(for mode: PhotosSelectionMode) throws -> [PHAsset] {
        switch mode {
        case .assets(let localIdentifiers):
            return fetchAssets(with: localIdentifiers)
        case .album(let localIdentifier, _):
            return try fetchAlbumAssets(localIdentifier: localIdentifier)
        case .library:
            return fetchLibraryAssets()
        }
    }

    static func imageFetchOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        options.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared]
        options.predicate = NSPredicate(
            format: "mediaType == %d",
            PHAssetMediaType.image.rawValue
        )
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: true)
        ]
        return options
    }

    static func fetchAssets(with localIdentifiers: [String]) -> [PHAsset] {
        let result = PHAsset.fetchAssets(
            withLocalIdentifiers: localIdentifiers,
            options: imageFetchOptions()
        )
        var assetsByIdentifier: [String: PHAsset] = [:]
        assetsByIdentifier.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            assetsByIdentifier[asset.localIdentifier] = asset
        }

        return localIdentifiers.compactMap { assetsByIdentifier[$0] }
    }

    static func fetchAlbumAssets(localIdentifier: String) throws -> [PHAsset] {
        let result = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [localIdentifier],
            options: nil
        )

        guard let collection = result.firstObject else {
            throw PhotosLibraryAssetExporterError.albumNotFound(localIdentifier)
        }

        return assets(from: PHAsset.fetchAssets(in: collection, options: imageFetchOptions()))
    }

    static func fetchLibraryAssets() -> [PHAsset] {
        assets(from: PHAsset.fetchAssets(with: imageFetchOptions()))
    }

    static func assets(from result: PHFetchResult<PHAsset>) -> [PHAsset] {
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    static func resource(
        for asset: PHAsset,
        representation: PhotosAssetRepresentation
    ) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)

        switch representation {
        case .original:
            return resources.first { $0.type == .photo }
                ?? resources.first { $0.type == .alternatePhoto }
        case .current:
            return resources.first { $0.type == .fullSizePhoto }
                ?? resources.first { $0.type == .photo }
                ?? resources.first { $0.type == .alternatePhoto }
        }
    }

    static func write(
        _ resource: PHAssetResource,
        to destinationURL: URL,
        allowsNetworkAccess: Bool
    ) async throws {
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = allowsNetworkAccess

        try await PHAssetResourceManager.default().writeData(
            for: resource,
            toFile: destinationURL,
            options: options
        )
    }

    static func stableFallbackName(for localIdentifier: String) -> String {
        let sanitizedIdentifier = localIdentifier
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return sanitizedIdentifier.isEmpty ? "photos_asset" : sanitizedIdentifier
    }

    static func exportFailureReason(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == PHPhotosErrorDomain,
           PHPhotosError.Code(rawValue: nsError.code) == .networkAccessRequired {
            return "Original asset is stored in iCloud and network access is disabled."
        }

        return error.localizedDescription
    }

    static func runCancellableDetached<T>(
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let task = Task<T, Error>.detached(priority: .utility) {
            try await operation()
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
#endif
