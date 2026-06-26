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

    init(
        selection: PhotosSelection,
        outputFolderURL: URL?,
        datasetName: String = "Photos Library",
        exportOptions: PhotosLibraryExportOptions = .unrestricted
    ) {
        self.selection = selection
        self.outputFolderURL = outputFolderURL
        self.datasetName = datasetName
        self.exportOptions = exportOptions
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
        PhotosMaterializationProgressHandler?
    ) async throws -> PhotosMaterializationResult

    private let materializeSelection: MaterializeSelection
    private let pipelineService: AnalysisPipelineService

    init(
        materializeSelection: @escaping MaterializeSelection = { selection, options, progressHandler in
            try await PhotosLibraryAssetExporter().export(
                selection: selection,
                options: options,
                progressHandler: progressHandler
            )
        },
        pipelineService: AnalysisPipelineService = AnalysisPipelineService()
    ) {
        self.materializeSelection = materializeSelection
        self.pipelineService = pipelineService
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
        let materializationResult = try await materializeSelection(
            request.selection,
            request.exportOptions,
            { snapshot in
                progressHandler?(preparationMapper.map(snapshot))
            }
        )
        defer {
            materializationResult.workspace.cleanup()
        }

        let pipelineResult = try await pipelineService.runPreparedFiles(
            request: PreparedAnalysisPipelineRequest(
                sourceFolderURL: materializationResult.workspace.directoryURL,
                packageDatasetName: request.datasetName,
                outputFolderURL: request.outputFolderURL,
                fileURLs: materializationResult.fileURLs,
                displayInfoByFileURL: materializationResult.displayInfoByFileURL
            ),
            progressHandler: progressHandler
        )

        return PhotosAnalysisPipelineResult(
            pipelineResult: pipelineResult,
            skippedAssets: materializationResult.skippedAssets
        )
    }
}
