//
//  AIAnalysisPackageExporter.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation

/// Exports normalized analysis data for downstream AI workflows.
final class AIAnalysisPackageExporter {
    /// Creates an AI analysis package exporter.
    nonisolated init() {}

    /// Creates an AI analysis package with normalized metadata and statistics JSON files.
    /// - Parameters:
    ///   - folderURL: The original folder URL analyzed by PhotoAnalyzer.
    ///   - metadata: The rich export metadata produced by the analysis pipeline.
    ///   - sourceFileURLs: The analyzed source image files in contact sheet order.
    ///   - statistics: The aggregate statistics produced from the photos.
    /// - Returns: The URL of the created package folder.
    /// - Throws: File system or JSON encoding errors.
    nonisolated func exportPackage(
        for folderURL: URL,
        metadata: [ExportPhotoMetadata],
        sourceFileURLs: [URL],
        statistics: PhotoStatistics,
        paths: AIAnalysisPackagePaths
    ) async throws -> URL {
        print("AI package export started")

        let paths = try exportDataFiles(
            for: folderURL,
            metadata: metadata,
            sourceFileURLs: sourceFileURLs,
            statistics: statistics,
            paths: paths
        )

        try await exportContactSheet(
            folderURL: folderURL,
            sourceFileURLs: sourceFileURLs,
            paths: paths
        )

        print("AI package export completed")
        return paths.packageURL
    }

    /// Creates the AI package folder and writes the JSON payloads.
    /// - Parameters:
    ///   - folderURL: The original folder URL analyzed by PhotoAnalyzer.
    ///   - metadata: The rich export metadata produced by the analysis pipeline.
    ///   - sourceFileURLs: The analyzed source image files in contact sheet order.
    ///   - statistics: The aggregate statistics produced from the photos.
    /// - Returns: The package paths used by subsequent export phases.
    /// - Throws: File system or JSON encoding errors.
    nonisolated func exportDataFiles(
        for folderURL: URL,
        metadata: [ExportPhotoMetadata],
        sourceFileURLs: [URL],
        statistics: PhotoStatistics,
        paths: AIAnalysisPackagePaths
    ) throws -> AIAnalysisPackagePaths {
        print("AI package path: \(paths.packageURL.path)")
        try FileManager.default.createDirectory(at: paths.packageURL, withIntermediateDirectories: true)

        let jsonWriter = JSONFileWriter()
        let indexedMetadata = metadataWithThumbnailIndexes(
            metadata,
            sourceFileURLs: sourceFileURLs
        )
        try jsonWriter.write(indexedMetadata, to: paths.metadataURL)

        let statisticsPayload = AIStatisticsPayload(statistics: statistics)
        try jsonWriter.write(statisticsPayload, to: paths.statisticsURL)

        return paths
    }

    /// Adds contact sheet thumbnail indexes to metadata records.
    /// - Parameters:
    ///   - metadata: ExifTool metadata records.
    ///   - sourceFileURLs: The analyzed source image files in contact sheet order.
    /// - Returns: Metadata records augmented with contact sheet indexes.
    nonisolated private func metadataWithThumbnailIndexes(
        _ metadata: [ExportPhotoMetadata],
        sourceFileURLs: [URL]
    ) -> [IndexedExportPhotoMetadata] {
        var indexByPath: [String: String] = [:]
        var indexByFileName: [String: String] = [:]

        for (offset, url) in sourceFileURLs.enumerated() {
            let index = ThumbnailIndexFormatter.string(from: offset + 1)
            indexByPath[url.path] = index
            indexByFileName[url.lastPathComponent] = index
        }

        return metadata.map { metadata in
            let thumbnailIndex = metadata.sourceFile.flatMap { indexByPath[$0] }
                ?? metadata.fileName.flatMap { indexByFileName[$0] }

            return IndexedExportPhotoMetadata(
                metadata: metadata,
                thumbnailIndex: thumbnailIndex
            )
        }
    }

    /// Generates the package contact sheet and index TSV.
    /// - Parameters:
    ///   - folderURL: The original folder URL analyzed by PhotoAnalyzer.
    ///   - sourceFileURLs: The analyzed source image files in contact sheet order.
    ///   - paths: The package paths created by `exportDataFiles`.
    /// - Throws: File system or image encoding errors.
    nonisolated func exportContactSheet(
        folderURL: URL,
        sourceFileURLs: [URL],
        paths: AIAnalysisPackagePaths
    ) async throws {
        let contactSheetExporter = ContactSheetExporter()
        try await contactSheetExporter.exportContactSheet(
            folderURL: folderURL,
            fileURLs: sourceFileURLs,
            paths: paths
        )
    }
}
