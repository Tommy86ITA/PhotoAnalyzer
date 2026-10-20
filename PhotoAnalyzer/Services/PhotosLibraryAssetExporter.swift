//
//  PhotosLibraryAssetExporter.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import AppKit
import Foundation
import OSLog

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
    let maximumConcurrentDownloads: Int

    init(
        maximumAssetCount: Int? = nil,
        maximumConcurrentDownloads: Int = PhotosDownloadConcurrency.recommended
    ) {
        self.maximumAssetCount = maximumAssetCount
        self.maximumConcurrentDownloads = PhotosDownloadConcurrency.clamped(maximumConcurrentDownloads)
    }

    static let unrestricted = PhotosLibraryExportOptions()
}

/// Progress emitted while Photos assets are exported into the temporary workspace.
typealias PhotosMaterializationProgressHandler = @Sendable (ProgressSnapshot) -> Void
typealias PhotosMaterializedAssetHandler = @Sendable (Int, MaterializedPhotosAsset) async throws -> Void

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
            metadataCacheMaximumSizeMB: MetadataCacheSizeLimit.mb512.rawValue,
            progressHandler: nil,
            materializedAssetHandler: nil
        )
    }

    func export(
        selection: PhotosSelection,
        options: PhotosLibraryExportOptions = .unrestricted,
        metadataCacheMaximumSizeMB: Int = MetadataCacheSizeLimit.mb512.rawValue,
        progressHandler: PhotosMaterializationProgressHandler?,
        materializedAssetHandler: PhotosMaterializedAssetHandler? = nil
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
                metadataCacheMaximumSizeMB: metadataCacheMaximumSizeMB,
                workspaceFactory: workspaceFactory,
                progressHandler: progressHandler,
                materializedAssetHandler: materializedAssetHandler
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
private enum PendingPhotosAssetExportKind: @unchecked Sendable {
    case original(PHAssetResource)
    case preview(PHAsset)
}

private struct PendingPhotosAssetExport: @unchecked Sendable {
    let sourceIndex: Int
    let kind: PendingPhotosAssetExportKind
    let materializedAsset: MaterializedPhotosAsset
}

private struct NetworkPhotosAssetExportResult: Sendable {
    let sourceIndex: Int
    let assetLocalIdentifier: String
    let materializedAsset: MaterializedPhotosAsset?
    let failureReason: String?
}

private enum PhotosPreviewRequestError: LocalizedError {
    case networkAccessRequired
    case cancelled
    case unavailable
    case couldNotEncode

    var errorDescription: String? {
        switch self {
        case .networkAccessRequired:
            "Preview is stored in iCloud and network access is disabled."
        case .cancelled:
            "Preview request was cancelled."
        case .unavailable:
            "Photos could not create a preview for this asset."
        case .couldNotEncode:
            "PhotoAnalyzer could not encode the Photos preview."
        }
    }
}

nonisolated private final class PhotosDownloadProgressTracker: @unchecked Sendable {
    private static let unitsPerAsset: Double = 1_000

    private let lock = NSLock()
    private let completedBeforeDownloads: Int
    private let totalAssetCount: Int
    private let progressHandler: PhotosMaterializationProgressHandler?
    private var fractionBySourceIndex: [Int: Double] = [:]

    init(
        completedBeforeDownloads: Int,
        totalAssetCount: Int,
        progressHandler: PhotosMaterializationProgressHandler?
    ) {
        self.completedBeforeDownloads = completedBeforeDownloads
        self.totalAssetCount = totalAssetCount
        self.progressHandler = progressHandler
    }

    func update(sourceIndex: Int, fractionCompleted: Double) {
        let snapshot: ProgressSnapshot

        lock.lock()
        let clampedFraction = min(max(fractionCompleted, 0), 1)
        fractionBySourceIndex[sourceIndex] = max(
            fractionBySourceIndex[sourceIndex] ?? 0,
            clampedFraction
        )
        let completedAssetCount = Double(completedBeforeDownloads)
            + fractionBySourceIndex.values.reduce(0, +)
        snapshot = ProgressSnapshot(
            completedUnitCount: Int64((completedAssetCount * Self.unitsPerAsset).rounded()),
            totalUnitCount: Int64(max(1, totalAssetCount)) * Int64(Self.unitsPerAsset),
            message: "Downloading required Photos data from iCloud..."
        )
        lock.unlock()

        progressHandler?(snapshot)
    }

    func complete(sourceIndex: Int) {
        update(sourceIndex: sourceIndex, fractionCompleted: 1)
    }
}

nonisolated private final class PhotosResourceRequestState: @unchecked Sendable {
    private let lock = NSLock()
    private let resourceManager: PHAssetResourceManager
    private var requestID = PHInvalidAssetResourceDataRequestID
    private var cancellationRequested = false

    init(resourceManager: PHAssetResourceManager) {
        self.resourceManager = resourceManager
    }

    func register(requestID: PHAssetResourceDataRequestID) {
        lock.lock()
        self.requestID = requestID
        let shouldCancel = cancellationRequested && requestID != PHInvalidAssetResourceDataRequestID
        lock.unlock()

        if shouldCancel {
            resourceManager.cancelDataRequest(requestID)
        }
    }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        let requestID = requestID
        lock.unlock()

        if requestID != PHInvalidAssetResourceDataRequestID {
            resourceManager.cancelDataRequest(requestID)
        }
    }
}

nonisolated private final class PhotosImageRequestState: @unchecked Sendable {
    private let lock = NSLock()
    private let imageManager: PHImageManager
    private var requestID = PHInvalidImageRequestID
    private var cancellationRequested = false

    init(imageManager: PHImageManager) {
        self.imageManager = imageManager
    }

    func register(requestID: PHImageRequestID) {
        lock.lock()
        self.requestID = requestID
        let shouldCancel = cancellationRequested && requestID != PHInvalidImageRequestID
        lock.unlock()

        if shouldCancel {
            imageManager.cancelImageRequest(requestID)
        }
    }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        let requestID = requestID
        lock.unlock()

        if requestID != PHInvalidImageRequestID {
            imageManager.cancelImageRequest(requestID)
        }
    }
}

nonisolated private final class PhotosPreviewContinuation: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<NSImage, Error>?

    init(_ continuation: CheckedContinuation<NSImage, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<NSImage, Error>) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()
        continuation.resume(with: result)
    }
}

nonisolated private final class PhotosResourceFileWriter: @unchecked Sendable {
    private let lock = NSLock()
    private var fileHandle: FileHandle?
    private var storedError: Error?

    init(destinationURL: URL, fileManager: FileManager = .default) throws {
        guard fileManager.createFile(atPath: destinationURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        fileHandle = try FileHandle(forWritingTo: destinationURL)
    }

    @discardableResult
    func append(_ data: Data) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard storedError == nil, let fileHandle else {
            return false
        }

        do {
            try fileHandle.write(contentsOf: data)
            return true
        } catch {
            storedError = error
            return false
        }
    }

    func finish() -> Error? {
        lock.lock()
        defer { lock.unlock() }

        if let fileHandle {
            do {
                try fileHandle.close()
            } catch where storedError == nil {
                storedError = error
            } catch {
                // Preserve the first write error.
            }
            self.fileHandle = nil
        }

        return storedError
    }
}

private extension PhotosLibraryAssetExporter {
    static func exportAuthorizedAssets(
        _ assets: [PHAsset],
        selection: PhotosSelection,
        options: PhotosLibraryExportOptions,
        metadataCacheMaximumSizeMB: Int,
        workspaceFactory: @Sendable () throws -> TemporaryAssetWorkspace,
        progressHandler: PhotosMaterializationProgressHandler?,
        materializedAssetHandler: PhotosMaterializedAssetHandler?
    ) async throws -> PhotosMaterializationResult {
        if let maximumAssetCount = options.maximumAssetCount,
           assets.count > maximumAssetCount {
            throw PhotosLibraryAssetExporterError.assetLimitExceeded(
                count: assets.count,
                limit: maximumAssetCount
            )
        }

        let workspace = try workspaceFactory()
        let normalizedCacheLimit = MetadataCacheSizeLimit.normalizedRawValue(metadataCacheMaximumSizeMB)
        let metadataCacheMaximumSizeBytes = MetadataCacheSizeLimit(rawValue: normalizedCacheLimit)?.byteCount
            ?? MetadataCacheSizeLimit.mb512.byteCount
        let metadataCacheService = MetadataCacheService()
        let exifToolService = ExifToolService()
        var shouldCleanupWorkspace = true
        defer {
            if shouldCleanupWorkspace {
                workspace.cleanup()
            }
        }

        var exportedAssetsByIndex: [Int: MaterializedPhotosAsset] = [:]
        var pendingNetworkExports: [PendingPhotosAssetExport] = []
        var skippedAssets: [PhotosAssetExportFailure] = []
        var completedAssetCount = 0
        exportedAssetsByIndex.reserveCapacity(assets.count)
        pendingNetworkExports.reserveCapacity(assets.count)

        var estimatedTemporaryBytes: Int64 = 0
        for asset in assets where asset.mediaType == .image {
            let sourceKey = MetadataCacheSourceKey.photosAsset(
                localIdentifier: asset.localIdentifier,
                representation: selection.representation,
                modificationDate: asset.modificationDate
            )
            let cachedData = metadataCacheService.cachedMetadataData(
                for: sourceKey,
                maximumSizeBytes: metadataCacheMaximumSizeBytes
            )
            let usesPreview = cachedData.flatMap {
                try? exifToolService.decodeAnalysisMetadata(from: $0)
            } != nil
            let assetEstimate = AnalysisDiskSpaceEstimator.temporaryBytes(
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight,
                usesPreview: usesPreview
            )
            let sum = estimatedTemporaryBytes.addingReportingOverflow(assetEstimate)
            estimatedTemporaryBytes = sum.overflow ? Int64.max : sum.partialValue
        }
        try DiskSpacePreflightService().requireAvailableSpace(
            at: workspace.directoryURL,
            requirement: DiskSpaceRequirement(
                estimatedBytes: estimatedTemporaryBytes,
                reserveBytes: AnalysisDiskSpaceEstimator.temporaryReserveBytes
            )
        )

        emitProgress(
            completedAssetCount: 0,
            totalAssetCount: assets.count,
            message: "Checking local Photos originals...",
            progressHandler: progressHandler
        )

        // Probe every resource without network access first. This lets Photos serve originals
        // retained in its local cache before any iCloud download can block the export queue.
        for (index, asset) in assets.enumerated() {
            try Task.checkCancellation()

            let localIdentifier = asset.localIdentifier

            guard asset.mediaType == .image else {
                skippedAssets.append(PhotosAssetExportFailure(
                    assetLocalIdentifier: localIdentifier,
                    reason: "Only image assets are supported."
                ))
                completedAssetCount += 1
                emitProgress(
                    completedAssetCount: completedAssetCount,
                    totalAssetCount: assets.count,
                    message: "Checking local Photos originals...",
                    progressHandler: progressHandler
                )
                continue
            }

            guard let resource = Self.resource(for: asset, representation: selection.representation) else {
                skippedAssets.append(PhotosAssetExportFailure(
                    assetLocalIdentifier: localIdentifier,
                    reason: "No exportable image resource was found."
                ))
                completedAssetCount += 1
                emitProgress(
                    completedAssetCount: completedAssetCount,
                    totalAssetCount: assets.count,
                    message: "Checking local Photos originals...",
                    progressHandler: progressHandler
                )
                continue
            }

            let metadataCacheSourceKey = MetadataCacheSourceKey.photosAsset(
                localIdentifier: localIdentifier,
                representation: selection.representation,
                modificationDate: asset.modificationDate
            )
            let cachedMetadataData = metadataCacheService.cachedMetadataData(
                for: metadataCacheSourceKey,
                maximumSizeBytes: metadataCacheMaximumSizeBytes
            )
            let hasValidCachedMetadata = cachedMetadataData.flatMap {
                try? exifToolService.decodeAnalysisMetadata(from: $0)
            } != nil
            let destinationURL = workspace.fileURL(
                preferredFilename: hasValidCachedMetadata
                    ? Self.previewFilename(for: resource.originalFilename)
                    : resource.originalFilename,
                fallbackBasename: Self.stableFallbackName(for: localIdentifier)
            )
            let materializedAsset = MaterializedPhotosAsset(
                assetLocalIdentifier: localIdentifier,
                originalFilename: resource.originalFilename,
                fileURL: destinationURL,
                representation: selection.representation,
                metadataCacheSourceKey: metadataCacheSourceKey
            )

            if hasValidCachedMetadata {
                do {
                    try await Self.writePreview(
                        for: asset,
                        representation: selection.representation,
                        to: destinationURL,
                        allowsNetworkAccess: false,
                        progressHandler: nil
                    )
                    exportedAssetsByIndex[index] = materializedAsset
                    try await materializedAssetHandler?(index, materializedAsset)
                    completedAssetCount += 1
                    emitProgress(
                        completedAssetCount: completedAssetCount,
                        totalAssetCount: assets.count,
                        message: "Using cached metadata and Photos previews...",
                        progressHandler: progressHandler
                    )
                } catch {
                    try? FileManager.default.removeItem(at: destinationURL)

                    if selection.allowsNetworkAccess && Self.requiresNetworkAccess(error) {
                        pendingNetworkExports.append(PendingPhotosAssetExport(
                            sourceIndex: index,
                            kind: .preview(asset),
                            materializedAsset: materializedAsset
                        ))
                    } else {
                        skippedAssets.append(PhotosAssetExportFailure(
                            assetLocalIdentifier: localIdentifier,
                            reason: Self.exportFailureReason(for: error)
                        ))
                        completedAssetCount += 1
                    }
                }
                continue
            }

            do {
                try await Self.write(
                    resource,
                    to: destinationURL,
                    allowsNetworkAccess: false
                )
                exportedAssetsByIndex[index] = materializedAsset
                try await materializedAssetHandler?(index, materializedAsset)
                completedAssetCount += 1
                emitProgress(
                    completedAssetCount: completedAssetCount,
                    totalAssetCount: assets.count,
                    message: "Using local Photos originals...",
                    progressHandler: progressHandler
                )
            } catch {
                try? FileManager.default.removeItem(at: destinationURL)

                if selection.allowsNetworkAccess && Self.requiresNetworkAccess(error) {
                    pendingNetworkExports.append(PendingPhotosAssetExport(
                        sourceIndex: index,
                        kind: .original(resource),
                        materializedAsset: materializedAsset
                    ))
                } else {
                    skippedAssets.append(PhotosAssetExportFailure(
                        assetLocalIdentifier: localIdentifier,
                        reason: Self.exportFailureReason(for: error)
                    ))
                    completedAssetCount += 1
                    emitProgress(
                        completedAssetCount: completedAssetCount,
                        totalAssetCount: assets.count,
                        message: "Checking local Photos originals...",
                        progressHandler: progressHandler
                    )
                }
            }
        }

        if !pendingNetworkExports.isEmpty {
            emitProgress(
                completedAssetCount: completedAssetCount,
                totalAssetCount: assets.count,
                message: "Downloading required Photos data from iCloud...",
                progressHandler: progressHandler
            )

            let downloadProgressTracker = PhotosDownloadProgressTracker(
                completedBeforeDownloads: completedAssetCount,
                totalAssetCount: assets.count,
                progressHandler: progressHandler
            )
            let maximumConcurrentDownloads = min(
                options.maximumConcurrentDownloads,
                pendingNetworkExports.count
            )
            var nextPendingExportIndex = 0

            try await withThrowingTaskGroup(of: NetworkPhotosAssetExportResult.self) { group in
                for _ in 0..<maximumConcurrentDownloads {
                    let pendingExport = pendingNetworkExports[nextPendingExportIndex]
                    nextPendingExportIndex += 1
                    group.addTask {
                        try await Self.download(
                            pendingExport,
                            progressTracker: downloadProgressTracker
                        )
                    }
                }

                while let downloadResult = try await group.next() {
                    if let materializedAsset = downloadResult.materializedAsset {
                        exportedAssetsByIndex[downloadResult.sourceIndex] = materializedAsset
                        try await materializedAssetHandler?(downloadResult.sourceIndex, materializedAsset)
                    } else if let failureReason = downloadResult.failureReason {
                        skippedAssets.append(PhotosAssetExportFailure(
                            assetLocalIdentifier: downloadResult.assetLocalIdentifier,
                            reason: failureReason
                        ))
                    }

                    downloadProgressTracker.complete(sourceIndex: downloadResult.sourceIndex)

                    if nextPendingExportIndex < pendingNetworkExports.count {
                        let pendingExport = pendingNetworkExports[nextPendingExportIndex]
                        nextPendingExportIndex += 1
                        group.addTask {
                            try await Self.download(
                                pendingExport,
                                progressTracker: downloadProgressTracker
                            )
                        }
                    }
                }
            }
        }

        let exportedAssets = exportedAssetsByIndex
            .sorted { $0.key < $1.key }
            .map(\.value)

        guard !exportedAssets.isEmpty else {
            throw PhotosLibraryAssetExporterError.noExportableAssets
        }

        let result = PhotosMaterializationResult(
            assets: exportedAssets,
            skippedAssets: skippedAssets,
            workspace: workspace
        )
        shouldCleanupWorkspace = false
        return result
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

    static func previewFilename(for originalFilename: String?) -> String {
        let basename = originalFilename.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        } ?? "photos_asset"
        return "\(basename)_preview.jpg"
    }

    static func writePreview(
        for asset: PHAsset,
        representation: PhotosAssetRepresentation,
        to destinationURL: URL,
        allowsNetworkAccess: Bool,
        progressHandler: (@Sendable (Double) -> Void)?
    ) async throws {
        let image = try await requestPreview(
            for: asset,
            representation: representation,
            allowsNetworkAccess: allowsNetworkAccess,
            progressHandler: progressHandler
        )

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let jpegData = NSBitmapImageRep(cgImage: cgImage).representation(
                using: .jpeg,
                properties: [.compressionFactor: 0.85]
              ) else {
            throw PhotosPreviewRequestError.couldNotEncode
        }

        try jpegData.write(to: destinationURL, options: .atomic)
    }

    static func requestPreview(
        for asset: PHAsset,
        representation: PhotosAssetRepresentation,
        allowsNetworkAccess: Bool,
        progressHandler: (@Sendable (Double) -> Void)?
    ) async throws -> NSImage {
        try Task.checkCancellation()

        let imageManager = PHImageManager.default()
        let requestState = PhotosImageRequestState(imageManager: imageManager)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = allowsNetworkAccess
        options.version = representation == .original ? .original : .current
        options.progressHandler = { fractionCompleted, _, _, _ in
            progressHandler?(fractionCompleted)
        }

        let image = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<NSImage, Error>) in
                let continuationState = PhotosPreviewContinuation(continuation)
                let requestID = imageManager.requestImage(
                    for: asset,
                    targetSize: ContactSheetLayout.thumbnailSize,
                    contentMode: .aspectFit,
                    options: options
                ) { image, info in
                    if info?[PHImageResultIsDegradedKey] as? Bool == true {
                        return
                    }
                    if info?[PHImageCancelledKey] as? Bool == true {
                        continuationState.resume(with: .failure(PhotosPreviewRequestError.cancelled))
                    } else if let error = info?[PHImageErrorKey] as? Error {
                        continuationState.resume(with: .failure(error))
                    } else if let image {
                        continuationState.resume(with: .success(image))
                    } else if info?[PHImageResultIsInCloudKey] as? Bool == true {
                        continuationState.resume(with: .failure(PhotosPreviewRequestError.networkAccessRequired))
                    } else {
                        continuationState.resume(with: .failure(PhotosPreviewRequestError.unavailable))
                    }
                }
                requestState.register(requestID: requestID)
            }
        } onCancel: {
            requestState.cancel()
        }

        try Task.checkCancellation()
        return image
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

    static func download(
        _ pendingExport: PendingPhotosAssetExport,
        progressTracker: PhotosDownloadProgressTracker
    ) async throws -> NetworkPhotosAssetExportResult {
        let maximumAttempts = PhotosCloudRetryPolicy.maximumAttempts
        var lastError: Error?

        for attempt in 1...maximumAttempts {
            do {
                try Task.checkCancellation()
                try? FileManager.default.removeItem(at: pendingExport.materializedAsset.fileURL)

                let progressHandler: @Sendable (Double) -> Void = { fractionCompleted in
                    progressTracker.update(
                        sourceIndex: pendingExport.sourceIndex,
                        fractionCompleted: fractionCompleted
                    )
                }

                switch pendingExport.kind {
                case .original(let resource):
                    try await writeCancellable(
                        resource,
                        to: pendingExport.materializedAsset.fileURL,
                        progressHandler: progressHandler
                    )
                case .preview(let asset):
                    try await writePreview(
                        for: asset,
                        representation: pendingExport.materializedAsset.representation,
                        to: pendingExport.materializedAsset.fileURL,
                        allowsNetworkAccess: true,
                        progressHandler: progressHandler
                    )
                }

                return NetworkPhotosAssetExportResult(
                    sourceIndex: pendingExport.sourceIndex,
                    assetLocalIdentifier: pendingExport.materializedAsset.assetLocalIdentifier,
                    materializedAsset: pendingExport.materializedAsset,
                    failureReason: nil
                )
            } catch {
                try? FileManager.default.removeItem(at: pendingExport.materializedAsset.fileURL)

                if Task.isCancelled || error is CancellationError {
                    throw CancellationError()
                }

                lastError = error
                guard attempt < maximumAttempts, PhotosCloudRetryPolicy.shouldRetry(error) else {
                    break
                }

                #if DEBUG
                AppLogger.export.warning(
                    "Retrying iCloud asset \(pendingExport.materializedAsset.assetLocalIdentifier, privacy: .private), attempt \(attempt + 1, privacy: .public) of \(maximumAttempts, privacy: .public)"
                )
                #endif
                try await Task.sleep(nanoseconds: PhotosCloudRetryPolicy.delayNanoseconds(afterAttempt: attempt))
            }
        }

        let error = lastError ?? PhotosPreviewRequestError.unavailable
        return NetworkPhotosAssetExportResult(
            sourceIndex: pendingExport.sourceIndex,
            assetLocalIdentifier: pendingExport.materializedAsset.assetLocalIdentifier,
            materializedAsset: nil,
            failureReason: exportFailureReason(for: error)
        )
    }

    static func writeCancellable(
        _ resource: PHAssetResource,
        to destinationURL: URL,
        progressHandler: (@Sendable (Double) -> Void)?
    ) async throws {
        try Task.checkCancellation()

        let resourceManager = PHAssetResourceManager.default()
        let requestState = PhotosResourceRequestState(resourceManager: resourceManager)
        let fileWriter = try PhotosResourceFileWriter(destinationURL: destinationURL)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        options.progressHandler = { fractionCompleted in
            progressHandler?(fractionCompleted)
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                let requestID = resourceManager.requestData(
                    for: resource,
                    options: options,
                    dataReceivedHandler: { data in
                        if !fileWriter.append(data) {
                            requestState.cancel()
                        }
                    },
                    completionHandler: { error in
                        let writingError = fileWriter.finish()

                        if let writingError {
                            continuation.resume(throwing: writingError)
                        } else if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                )
                requestState.register(requestID: requestID)
            }
        } onCancel: {
            requestState.cancel()
        }

        try Task.checkCancellation()
    }

    static func stableFallbackName(for localIdentifier: String) -> String {
        let sanitizedIdentifier = localIdentifier
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return sanitizedIdentifier.isEmpty ? "photos_asset" : sanitizedIdentifier
    }

    static func requiresNetworkAccess(_ error: Error) -> Bool {
        if case PhotosPreviewRequestError.networkAccessRequired = error {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == PHPhotosErrorDomain
            && PHPhotosError.Code(rawValue: nsError.code) == .networkAccessRequired
    }

    static func exportFailureReason(for error: Error) -> String {
        if requiresNetworkAccess(error) {
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
