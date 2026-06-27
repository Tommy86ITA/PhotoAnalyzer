//
//  AnalysisPipelineDependencies.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Foundation

/// Injectable collaborators used by the analysis pipeline.
nonisolated struct AnalysisPipelineDependencies: Sendable {
    typealias ScanImageFiles = @Sendable (
        _ folderURL: URL,
        _ includeSubfolders: Bool,
        _ expectedSupportedFileCount: Int?,
        _ progressHandler: (@Sendable (ProgressSnapshot) -> Void)?
    ) -> [URL]

    typealias AnalyzeFiles = @Sendable (
        _ fileURLs: [URL],
        _ metadataCacheSourceKeyByFileURL: [URL: MetadataCacheSourceKey],
        _ metadataCacheMaximumSizeMB: Int,
        _ progressHandler: (@Sendable (ProgressSnapshot) -> Void)?
    ) async throws -> FolderAnalysisResult

    typealias BuildStatistics = @Sendable (_ photos: [PhotoInfo]) -> PhotoStatistics

    typealias ExportDataFiles = @Sendable (
        _ folderURL: URL,
        _ metadata: [ExportPhotoMetadata],
        _ sourceFileURLs: [URL],
        _ statistics: PhotoStatistics,
        _ paths: AIAnalysisPackagePaths,
        _ displayInfoByFileURL: [URL: SourceFileDisplayInfo],
        _ progressHandler: (@Sendable (ProgressSnapshot) -> Void)?
    ) throws -> AIAnalysisPackagePaths

    typealias ExportContactSheet = @Sendable (
        _ folderURL: URL,
        _ sourceFileURLs: [URL],
        _ paths: AIAnalysisPackagePaths,
        _ displayInfoByFileURL: [URL: SourceFileDisplayInfo],
        _ progressHandler: (@Sendable (ProgressSnapshot) -> Void)?
    ) async throws -> Void

    typealias ArchivePackage = @Sendable (
        _ paths: AIAnalysisPackagePaths,
        _ progressHandler: (@Sendable (ProgressSnapshot) -> Void)?
    ) throws -> URL

    let scanImageFiles: ScanImageFiles
    let analyzeFiles: AnalyzeFiles
    let buildStatistics: BuildStatistics
    let exportDataFiles: ExportDataFiles
    let exportContactSheet: ExportContactSheet
    let archivePackage: ArchivePackage

    static let live = AnalysisPipelineDependencies(
        scanImageFiles: { folderURL, includeSubfolders, expectedSupportedFileCount, progressHandler in
            ImageFileScanner().imageFileURLs(
                in: folderURL,
                includeSubfolders: includeSubfolders,
                expectedSupportedFileCount: expectedSupportedFileCount,
                progressHandler: progressHandler
            )
        },
        analyzeFiles: { fileURLs, metadataCacheSourceKeyByFileURL, metadataCacheMaximumSizeMB, progressHandler in
            try await FolderAnalysisService().analyzeFilesWithExportMetadata(
                fileURLs,
                metadataCacheSourceKeyByFileURL: metadataCacheSourceKeyByFileURL,
                metadataCacheMaximumSizeMB: metadataCacheMaximumSizeMB,
                progressHandler: progressHandler
            )
        },
        buildStatistics: { photos in
            PhotoStatisticsService().buildStatistics(from: photos)
        },
        exportDataFiles: { folderURL, metadata, sourceFileURLs, statistics, paths, displayInfoByFileURL, progressHandler in
            try AIAnalysisPackageExporter().exportDataFiles(
                for: folderURL,
                metadata: metadata,
                sourceFileURLs: sourceFileURLs,
                statistics: statistics,
                paths: paths,
                displayInfoByFileURL: displayInfoByFileURL,
                progressHandler: progressHandler
            )
        },
        exportContactSheet: { folderURL, sourceFileURLs, paths, displayInfoByFileURL, progressHandler in
            try await AIAnalysisPackageExporter().exportContactSheet(
                folderURL: folderURL,
                sourceFileURLs: sourceFileURLs,
                paths: paths,
                displayInfoByFileURL: displayInfoByFileURL,
                progressHandler: progressHandler
            )
        },
        archivePackage: { paths, progressHandler in
            try AIAnalysisPackageExporter().archivePackage(
                paths: paths,
                progressHandler: progressHandler
            )
        }
    )
}
