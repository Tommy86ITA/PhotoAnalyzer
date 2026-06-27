//
//  CachedExifMetadataReader.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 27/06/2026.
//

import Foundation

/// Metadata decoded from ExifTool, with cache hit information for diagnostics.
nonisolated struct CachedExifMetadataReadResult: Sendable {
    let metadata: ExportPhotoMetadata
    let isCacheHit: Bool
}

/// Reads ExifTool metadata through the SQLite cache when possible.
nonisolated struct CachedExifMetadataReader: Sendable {
    private let exifToolService: ExifToolService
    private let metadataCacheService: MetadataCacheService
    private let maximumSizeBytes: Int64

    init(
        exifToolService: ExifToolService,
        metadataCacheService: MetadataCacheService,
        maximumSizeMB: Int
    ) {
        self.exifToolService = exifToolService
        self.metadataCacheService = metadataCacheService

        let normalizedLimit = MetadataCacheSizeLimit.normalizedRawValue(maximumSizeMB)
        maximumSizeBytes = MetadataCacheSizeLimit(rawValue: normalizedLimit)?.byteCount
            ?? MetadataCacheSizeLimit.mb512.byteCount
    }

    func readMetadata(
        for fileURL: URL,
        sourceKey: MetadataCacheSourceKey?,
        using runner: ExifToolRunner
    ) throws -> CachedExifMetadataReadResult? {
        let metadataData: Data
        let isCacheHit: Bool

        if let cachedData = metadataCacheService.cachedMetadataData(
            for: fileURL,
            sourceKey: sourceKey,
            maximumSizeBytes: maximumSizeBytes
        ) {
            metadataData = cachedData
            isCacheHit = true
        } else {
            metadataData = try exifToolService.extractAnalysisMetadataData(from: fileURL, using: runner)
            isCacheHit = false
        }

        guard let metadata = try exifToolService.decodeAnalysisMetadata(from: metadataData) else {
            return nil
        }

        if !isCacheHit {
            metadataCacheService.storeMetadataData(
                metadataData,
                for: fileURL,
                sourceKey: sourceKey,
                maximumSizeBytes: maximumSizeBytes
            )
        }

        return CachedExifMetadataReadResult(
            metadata: metadata,
            isCacheHit: isCacheHit
        )
    }
}
