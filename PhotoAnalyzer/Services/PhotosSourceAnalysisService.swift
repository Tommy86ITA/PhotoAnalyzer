//
//  PhotosSourceAnalysisService.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 20/06/2026.
//

import Foundation
import PhotosUI
import SwiftUI

/// Photos input variants supported by the backend.
nonisolated enum PhotosSourceAnalysisInput: Sendable {
    case pickerItems(
        [PhotosPickerItem],
        datasetName: String = "Photos Library",
        representation: PhotosAssetRepresentation = .original
    )
    case librarySelection(
        PhotosSelection,
        datasetName: String = "Photos Library",
        exportOptions: PhotosLibraryExportOptions = .unrestricted
    )
}

/// Facade that chooses the right Photos backend while preserving the file-based core pipeline.
nonisolated struct PhotosSourceAnalysisService: Sendable {
    typealias ProgressHandler = AnalysisPipelineService.ProgressHandler
    typealias MaterializePickerItems = @Sendable (
        [PhotosPickerItem],
        PhotosAssetRepresentation
    ) async throws -> PhotosMaterializationResult

    private let materializePickerItems: MaterializePickerItems
    private let photosPipelineService: PhotosAnalysisPipelineService
    private let pipelineService: AnalysisPipelineService

    init(
        materializePickerItems: @escaping MaterializePickerItems = { items, representation in
            try await PhotosPickerItemAssetExporter().export(
                items: items,
                representation: representation
            )
        },
        photosPipelineService: PhotosAnalysisPipelineService = PhotosAnalysisPipelineService(),
        pipelineService: AnalysisPipelineService = AnalysisPipelineService()
    ) {
        self.materializePickerItems = materializePickerItems
        self.photosPipelineService = photosPipelineService
        self.pipelineService = pipelineService
    }

    func run(
        input: PhotosSourceAnalysisInput,
        outputFolderURL: URL?,
        progressHandler: ProgressHandler?
    ) async throws -> PhotosAnalysisPipelineResult {
        switch input {
        case .pickerItems(let items, let datasetName, let representation):
            return try await runPickerItems(
                items,
                datasetName: datasetName,
                representation: representation,
                outputFolderURL: outputFolderURL,
                progressHandler: progressHandler
            )
        case .librarySelection(let selection, let datasetName, let exportOptions):
            return try await photosPipelineService.run(
                request: PhotosAnalysisPipelineRequest(
                    selection: selection,
                    outputFolderURL: outputFolderURL,
                    datasetName: datasetName,
                    exportOptions: exportOptions
                ),
                progressHandler: progressHandler
            )
        }
    }

    private func runPickerItems(
        _ items: [PhotosPickerItem],
        datasetName: String,
        representation: PhotosAssetRepresentation,
        outputFolderURL: URL?,
        progressHandler: ProgressHandler?
    ) async throws -> PhotosAnalysisPipelineResult {
        progressHandler?(
            AnalysisProgress(
                fractionCompleted: 0,
                message: "Preparing Photos assets...",
                phase: .preparingPhotos
            )
        )

        let materializationResult = try await materializePickerItems(items, representation)
        defer {
            materializationResult.workspace.cleanup()
        }

        let pipelineResult = try await pipelineService.runPreparedFiles(
            request: PreparedAnalysisPipelineRequest(
                sourceFolderURL: materializationResult.workspace.directoryURL,
                packageDatasetName: datasetName,
                outputFolderURL: outputFolderURL,
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
