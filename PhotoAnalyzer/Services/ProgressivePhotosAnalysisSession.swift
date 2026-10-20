//
//  ProgressivePhotosAnalysisSession.swift
//  PhotoAnalyzer
//

import Foundation
import OSLog

/// Keeps one ExifTool session alive while Photos assets arrive from local storage or iCloud.
actor ProgressivePhotosAnalysisSession {
    private struct Record {
        let sourceIndex: Int
        let photo: PhotoInfo
        let metadata: ExportPhotoMetadata
        let fileURL: URL
        let isCacheHit: Bool
    }

    private let metadataReader: CachedExifMetadataReader
    private let photoInfoMapper = PhotoInfoMapper()
    private let processPerFileRunner: ExifToolRunner
    private var persistentRunner: PersistentExifToolRunner?
    private var activeRunner: ExifToolRunner
    private var isUsingPersistentRunner: Bool
    private var recordsByFileURL: [URL: Record] = [:]

    init(metadataCacheMaximumSizeMB: Int) throws {
        let exifToolService = ExifToolService()
        metadataReader = CachedExifMetadataReader(
            exifToolService: exifToolService,
            metadataCacheService: MetadataCacheService(),
            maximumSizeMB: metadataCacheMaximumSizeMB
        )
        processPerFileRunner = try exifToolService.makeProcessPerFileRunner()

        if let runner = try? exifToolService.makePersistentRunner() {
            persistentRunner = runner
            activeRunner = runner
            isUsingPersistentRunner = true
        } else {
            persistentRunner = nil
            activeRunner = processPerFileRunner
            isUsingPersistentRunner = false
        }
    }

    func analyze(sourceIndex: Int, asset: MaterializedPhotosAsset) {
        guard recordsByFileURL[asset.fileURL] == nil else {
            return
        }

        do {
            try analyzeUsingActiveRunner(sourceIndex: sourceIndex, asset: asset)
        } catch let error as PersistentExifToolRunnerError where isUsingPersistentRunner {
            #if DEBUG
            AppLogger.analysis.warning(
                "Persistent ExifTool runner failed during progressive Photos analysis; using process-per-file fallback: \(error.localizedDescription, privacy: .public)"
            )
            #endif
            persistentRunner?.close()
            persistentRunner = nil
            activeRunner = processPerFileRunner
            isUsingPersistentRunner = false

            do {
                try analyzeUsingActiveRunner(sourceIndex: sourceIndex, asset: asset)
            } catch {
                logFailure(error, fileURL: asset.fileURL)
            }
        } catch {
            logFailure(error, fileURL: asset.fileURL)
        }
    }

    func analyzeRemaining(_ assets: [MaterializedPhotosAsset]) {
        for (sourceIndex, asset) in assets.enumerated() where recordsByFileURL[asset.fileURL] == nil {
            analyze(sourceIndex: sourceIndex, asset: asset)
        }
    }

    func finish(orderedAssets: [MaterializedPhotosAsset]) -> FolderAnalysisResult {
        persistentRunner?.close()
        persistentRunner = nil
        isUsingPersistentRunner = false

        let records = orderedAssets.compactMap { recordsByFileURL[$0.fileURL] }
        return FolderAnalysisResult(
            photos: records.map(\.photo),
            exportMetadata: records.map(\.metadata),
            fileURLs: records.map(\.fileURL),
            metadataCacheHitCount: records.count(where: \.isCacheHit)
        )
    }

    func close() {
        persistentRunner?.close()
        persistentRunner = nil
        isUsingPersistentRunner = false
    }

    private func analyzeUsingActiveRunner(
        sourceIndex: Int,
        asset: MaterializedPhotosAsset
    ) throws {
        guard let result = try metadataReader.readMetadata(
            for: asset.fileURL,
            sourceKey: asset.metadataCacheSourceKey,
            using: activeRunner
        ) else {
            return
        }

        recordsByFileURL[asset.fileURL] = Record(
            sourceIndex: sourceIndex,
            photo: photoInfoMapper.photoInfo(
                from: result.metadata,
                fallbackFileURL: asset.fileURL
            ),
            metadata: result.metadata,
            fileURL: asset.fileURL,
            isCacheHit: result.isCacheHit
        )
    }

    private func logFailure(_ error: Error, fileURL: URL) {
        AppLogger.analysis.warning(
            "Could not extract metadata for \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
    }
}
