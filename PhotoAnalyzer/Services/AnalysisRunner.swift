//
//  AnalysisRunner.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 28/06/2026.
//

import Foundation

/// Normalized result from either folder or Photos analysis pipelines.
struct AnalysisRunResult {
    let paths: AIAnalysisPackagePaths
    let statistics: PhotoStatistics
    let supportedFileCount: Int
    let analyzedPhotoCount: Int
    let packageError: AppErrorInfo?
}

/// Runs the concrete analysis pipelines and normalizes their results for UI coordination.
struct AnalysisRunner {
    /// Runs the folder-backed analysis pipeline.
    func runFolderAnalysis(
        folderURL: URL,
        outputFolderURL: URL,
        includeSubfolders: Bool,
        expectedSupportedFileCount: Int?,
        metadataCacheMaximumSizeMB: Int,
        exportDiagnosticReports: Bool,
        progressHandler: @escaping @Sendable (AnalysisProgress) -> Void
    ) async throws -> AnalysisRunResult {
        let result = try await AnalysisPipelineService().run(
            request: AnalysisPipelineRequest(
                folderURL: folderURL,
                outputFolderURL: outputFolderURL,
                includeSubfolders: includeSubfolders,
                expectedSupportedFileCount: expectedSupportedFileCount,
                metadataCacheMaximumSizeMB: metadataCacheMaximumSizeMB,
                exportDiagnosticReports: exportDiagnosticReports
            ),
            progressHandler: progressHandler
        )

        return AnalysisRunResult(
            paths: result.paths,
            statistics: result.statistics,
            supportedFileCount: result.supportedFileCount,
            analyzedPhotoCount: result.analyzedPhotoCount,
            packageError: nil
        )
    }

    /// Runs the Photos-backed analysis pipeline.
    func runPhotosAnalysis(
        selection: PhotosSelection,
        outputFolderURL: URL,
        datasetName: String,
        metadataCacheMaximumSizeMB: Int,
        exportDiagnosticReports: Bool,
        progressHandler: @escaping @Sendable (AnalysisProgress) -> Void
    ) async throws -> AnalysisRunResult {
        let result = try await PhotosAnalysisPipelineService().run(
            request: PhotosAnalysisPipelineRequest(
                selection: selection,
                outputFolderURL: outputFolderURL,
                datasetName: datasetName,
                metadataCacheMaximumSizeMB: metadataCacheMaximumSizeMB,
                exportDiagnosticReports: exportDiagnosticReports
            ),
            progressHandler: progressHandler
        )

        return AnalysisRunResult(
            paths: result.paths,
            statistics: result.statistics,
            supportedFileCount: result.supportedFileCount,
            analyzedPhotoCount: result.analyzedPhotoCount,
            packageError: AppErrorInfo.photosSkippedAssets(result.skippedAssets)
        )
    }
}
