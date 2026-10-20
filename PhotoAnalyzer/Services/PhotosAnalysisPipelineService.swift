//
//  PhotosAnalysisPipelineService.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 20/06/2026.
//

import Foundation

/// Input needed to run the file-based pipeline from a Photos Library selection.
nonisolated struct PhotosAnalysisPipelineRequest: Sendable {
    let selection: PhotosSelection
    let outputFolderURL: URL?
    let datasetName: String
    let exportOptions: PhotosLibraryExportOptions
    let metadataCacheMaximumSizeMB: Int
    let exportDiagnosticReports: Bool

    init(
        selection: PhotosSelection,
        outputFolderURL: URL?,
        datasetName: String = "Photos Library",
        exportOptions: PhotosLibraryExportOptions = .unrestricted,
        metadataCacheMaximumSizeMB: Int = MetadataCacheSizeLimit.mb512.rawValue,
        exportDiagnosticReports: Bool = false
    ) {
        self.selection = selection
        self.outputFolderURL = outputFolderURL
        self.datasetName = datasetName
        self.exportOptions = exportOptions
        self.metadataCacheMaximumSizeMB = metadataCacheMaximumSizeMB
        self.exportDiagnosticReports = exportDiagnosticReports
    }
}

/// Result produced by a Photos Library analysis run.
nonisolated struct PhotosAnalysisPipelineResult: Sendable {
    let pipelineResult: AnalysisPipelineResult
    let skippedAssets: [PhotosAssetExportFailure]

    var paths: AIAnalysisPackagePaths {
        pipelineResult.paths
    }

    var statistics: PhotoStatistics {
        pipelineResult.statistics
    }

    var supportedFileCount: Int {
        pipelineResult.supportedFileCount + skippedAssets.count
    }

    var analyzedPhotoCount: Int {
        pipelineResult.analyzedPhotoCount
    }
}

/// Bridges Photos Library selections into the existing physical-file analysis pipeline.
nonisolated struct PhotosAnalysisPipelineService: Sendable {
    typealias ProgressHandler = AnalysisPipelineService.ProgressHandler
    typealias MaterializeSelection = @Sendable (
        PhotosSelection,
        PhotosLibraryExportOptions,
        Int,
        PhotosMaterializationProgressHandler?,
        PhotosMaterializedAssetHandler?
    ) async throws -> PhotosMaterializationResult

    private let materializeSelection: MaterializeSelection
    private let pipelineService: AnalysisPipelineService
    private let progressiveAnalysisEnabled: Bool

    init(
        materializeSelection: @escaping MaterializeSelection = { selection, options, cacheSizeMB, progressHandler, assetHandler in
            try await PhotosLibraryAssetExporter().export(
                selection: selection,
                options: options,
                metadataCacheMaximumSizeMB: cacheSizeMB,
                progressHandler: progressHandler,
                materializedAssetHandler: assetHandler
            )
        },
        pipelineService: AnalysisPipelineService = AnalysisPipelineService(),
        progressiveAnalysisEnabled: Bool = true
    ) {
        self.materializeSelection = materializeSelection
        self.pipelineService = pipelineService
        self.progressiveAnalysisEnabled = progressiveAnalysisEnabled
    }

    func run(
        request: PhotosAnalysisPipelineRequest,
        progressHandler: ProgressHandler?
    ) async throws -> PhotosAnalysisPipelineResult {
        progressHandler?(
            AnalysisProgress(
                fractionCompleted: 0,
                message: "Preparing Photos assets...",
                phase: .preparingPhotos
            )
        )

        let preparationMapper = PipelineProgressMapper(
            startingUnitCount: 0,
            totalUnitCount: 10,
            allocatedUnitCount: 1,
            phase: .preparingPhotos
        )
        let materializationResult: PhotosMaterializationResult
        let progressiveAnalysisResult: FolderAnalysisResult?

        if progressiveAnalysisEnabled {
            let progressiveAnalysis = try ProgressivePhotosAnalysisSession(
                metadataCacheMaximumSizeMB: request.metadataCacheMaximumSizeMB
            )
            do {
                materializationResult = try await materializeSelection(
                    request.selection,
                    request.exportOptions,
                    request.metadataCacheMaximumSizeMB,
                    { snapshot in
                        progressHandler?(preparationMapper.map(snapshot))
                    },
                    { sourceIndex, asset in
                        await progressiveAnalysis.analyze(
                            sourceIndex: sourceIndex,
                            asset: asset
                        )
                    }
                )
            } catch {
                await progressiveAnalysis.close()
                throw error
            }

            await progressiveAnalysis.analyzeRemaining(materializationResult.assets)
            progressiveAnalysisResult = await progressiveAnalysis.finish(
                orderedAssets: materializationResult.assets
            )
        } else {
            materializationResult = try await materializeSelection(
                request.selection,
                request.exportOptions,
                request.metadataCacheMaximumSizeMB,
                { snapshot in
                    progressHandler?(preparationMapper.map(snapshot))
                },
                nil
            )
            progressiveAnalysisResult = nil
        }

        defer {
            materializationResult.workspace.cleanup()
        }

        let pipelineResult = try await pipelineService.runPreparedFiles(
            request: PreparedAnalysisPipelineRequest(
                sourceFolderURL: materializationResult.workspace.directoryURL,
                packageDatasetName: request.datasetName,
                outputFolderURL: request.outputFolderURL,
                fileURLs: materializationResult.fileURLs,
                displayInfoByFileURL: materializationResult.displayInfoByFileURL,
                metadataCacheSourceKeyByFileURL: materializationResult.metadataCacheSourceKeyByFileURL,
                metadataCacheMaximumSizeMB: request.metadataCacheMaximumSizeMB,
                exportDiagnosticReports: request.exportDiagnosticReports
            ),
            preanalyzedResult: progressiveAnalysisResult,
            progressHandler: progressHandler
        )

        return PhotosAnalysisPipelineResult(
            pipelineResult: pipelineResult,
            skippedAssets: materializationResult.skippedAssets
        )
    }
}
