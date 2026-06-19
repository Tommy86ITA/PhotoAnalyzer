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
nonisolated struct MaterializedPhotosAsset {
    let assetLocalIdentifier: String
    let originalFilename: String?
    let fileURL: URL
    let representation: PhotosAssetRepresentation
}

/// Result of exporting a Photos selection to physical files.
nonisolated struct PhotosMaterializationResult {
    let assets: [MaterializedPhotosAsset]
    let skippedAssets: [PhotosAssetExportFailure]
    let workspace: TemporaryAssetWorkspace

    var fileURLs: [URL] {
        assets.map(\.fileURL)
    }
}

/// Per-asset export failure, kept separate so partial Photos selections can still be analyzed.
nonisolated struct PhotosAssetExportFailure: Equatable, Sendable {
    let assetLocalIdentifier: String
    let reason: String
}

/// Errors produced while preparing Photos Library assets for file-based analysis.
nonisolated enum PhotosLibraryAssetExporterError: LocalizedError, Equatable {
    case photosUnavailable
    case unauthorized
    case unsupportedSelection
    case noExportableAssets

    var errorDescription: String? {
        switch self {
        case .photosUnavailable:
            "Photos Library access is not available on this platform."
        case .unauthorized:
            "PhotoAnalyzer is not authorized to access the Photos Library."
        case .unsupportedSelection:
            "This Photos Library selection is not supported yet."
        case .noExportableAssets:
            "No selected Photos assets could be exported for analysis."
        }
    }
}

/// Materializes Photos Library assets into a temporary workspace for ExifTool-based analysis.
final class PhotosLibraryAssetExporter {
    private let workspaceFactory: () throws -> TemporaryAssetWorkspace

    init(workspaceFactory: @escaping () throws -> TemporaryAssetWorkspace = {
        try TemporaryAssetWorkspace()
    }) {
        self.workspaceFactory = workspaceFactory
    }

    func export(selection: PhotosSelection) async throws -> PhotosMaterializationResult {
        #if canImport(Photos)
        try await requestReadAccessIfNeeded()

        guard case .assets(let localIdentifiers) = selection.mode else {
            throw PhotosLibraryAssetExporterError.unsupportedSelection
        }

        let workspace = try workspaceFactory()
        var exportedAssets: [MaterializedPhotosAsset] = []
        var skippedAssets: [PhotosAssetExportFailure] = []
        exportedAssets.reserveCapacity(localIdentifiers.count)

        let assetsByIdentifier = fetchAssets(with: localIdentifiers)

        for localIdentifier in localIdentifiers {
            try Task.checkCancellation()

            guard let asset = assetsByIdentifier[localIdentifier] else {
                skippedAssets.append(PhotosAssetExportFailure(
                    assetLocalIdentifier: localIdentifier,
                    reason: "Asset was not found in the Photos Library."
                ))
                continue
            }

            guard asset.mediaType == .image else {
                skippedAssets.append(PhotosAssetExportFailure(
                    assetLocalIdentifier: localIdentifier,
                    reason: "Only image assets are supported."
                ))
                continue
            }

            guard let resource = resource(for: asset, representation: selection.representation) else {
                skippedAssets.append(PhotosAssetExportFailure(
                    assetLocalIdentifier: localIdentifier,
                    reason: "No exportable image resource was found."
                ))
                continue
            }

            let destinationURL = workspace.fileURL(
                preferredFilename: resource.originalFilename,
                fallbackBasename: stableFallbackName(for: localIdentifier)
            )

            do {
                try await write(resource, to: destinationURL, allowsNetworkAccess: selection.allowsNetworkAccess)
                exportedAssets.append(MaterializedPhotosAsset(
                    assetLocalIdentifier: localIdentifier,
                    originalFilename: resource.originalFilename,
                    fileURL: destinationURL,
                    representation: selection.representation
                ))
            } catch {
                try? FileManager.default.removeItem(at: destinationURL)
                skippedAssets.append(PhotosAssetExportFailure(
                    assetLocalIdentifier: localIdentifier,
                    reason: error.localizedDescription
                ))
            }
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
        #else
        throw PhotosLibraryAssetExporterError.photosUnavailable
        #endif
    }
}

#if canImport(Photos)
private extension PhotosLibraryAssetExporter {
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

    func fetchAssets(with localIdentifiers: [String]) -> [String: PHAsset] {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        var assetsByIdentifier: [String: PHAsset] = [:]
        assetsByIdentifier.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            assetsByIdentifier[asset.localIdentifier] = asset
        }

        return assetsByIdentifier
    }

    func resource(
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

    func write(
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

    func stableFallbackName(for localIdentifier: String) -> String {
        let sanitizedIdentifier = localIdentifier
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return sanitizedIdentifier.isEmpty ? "photos_asset" : sanitizedIdentifier
    }
}
#endif
