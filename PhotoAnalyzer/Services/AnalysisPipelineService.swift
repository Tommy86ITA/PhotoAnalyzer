//
//  AnalysisPipelineService.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import Foundation

/// Input needed to run the full PhotoAnalyzer processing pipeline.
nonisolated struct AnalysisPipelineRequest: Sendable {
    let folderURL: URL
    let outputFolderURL: URL?
    let includeSubfolders: Bool
    let expectedSupportedFileCount: Int?
}

/// Result produced by the full PhotoAnalyzer processing pipeline.
nonisolated struct AnalysisPipelineResult: Sendable {
    let paths: AIAnalysisPackagePaths
    let statistics: PhotoStatistics
    let supportedFileCount: Int
    let analyzedPhotoCount: Int
}

/// Runs the complete analysis/export/archive pipeline without owning UI state.
nonisolated struct AnalysisPipelineService: Sendable {
    typealias ProgressHandler = @Sendable (AnalysisProgress) -> Void

    func run(
        request: AnalysisPipelineRequest,
        progressHandler: ProgressHandler?
    ) async throws -> AnalysisPipelineResult {
        let expectedPhotoCount = request.expectedSupportedFileCount ?? 0
        let pipelineTotalUnitCount = totalPipelineUnitCount(for: expectedPhotoCount)
        let packagePaths = AIAnalysisPackagePaths(
            datasetFolderURL: request.folderURL,
            outputFolderURL: request.outputFolderURL
        )

        let datasetAccessGranted = request.folderURL.startAccessingSecurityScopedResource()
        if !datasetAccessGranted {
            print("Warning: security-scoped access was not granted. Continuing anyway.")
        }

        let outputAccessGranted = request.outputFolderURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if datasetAccessGranted {
                request.folderURL.stopAccessingSecurityScopedResource()
            }

            if outputAccessGranted {
                request.outputFolderURL?.stopAccessingSecurityScopedResource()
            }
        }

        var completedPipelineUnitCount: Int64 = 0

        emitProgress(
            completedUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            message: "Scanning files...",
            progressHandler: progressHandler
        )
        let scanningProgressUnitCount = Int64(max(1, expectedPhotoCount))
        let scanningProgressHandler = progressMapper(
            startingUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            progressHandler: progressHandler
        )
        let fileURLs = try await runCancellableDetached {
            try Task.checkCancellation()
            return ImageFileScanner().imageFileURLs(
                in: request.folderURL,
                includeSubfolders: request.includeSubfolders,
                expectedSupportedFileCount: request.expectedSupportedFileCount,
                progressHandler: scanningProgressHandler
            )
        }
        try Task.checkCancellation()
        completedPipelineUnitCount += scanningProgressUnitCount
        emitProgress(
            completedUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            message: "Scanning files...",
            progressHandler: progressHandler
        )

        guard !fileURLs.isEmpty else {
            throw AnalysisPipelineError.noSupportedFiles
        }

        let metadataProgressUnitCount = Int64(max(1, fileURLs.count))
        let metadataProgressHandler = progressMapper(
            startingUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            progressHandler: progressHandler
        )
        let folderAnalysisResult = try await runCancellableDetached {
            try await FolderAnalysisService().analyzeFilesWithExportMetadata(
                fileURLs,
                progressHandler: metadataProgressHandler
            )
        }
        try Task.checkCancellation()
        completedPipelineUnitCount += metadataProgressUnitCount
        emitProgress(
            completedUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            message: "Reading metadata...",
            progressHandler: progressHandler
        )

        emitProgress(
            completedUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            message: "Generating statistics...",
            progressHandler: progressHandler
        )
        let generatedStatistics = try await runCancellableDetached {
            try Task.checkCancellation()
            return PhotoStatisticsService().buildStatistics(from: folderAnalysisResult.photos)
        }
        try Task.checkCancellation()
        completedPipelineUnitCount += 1
        emitProgress(
            completedUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            message: "Generating statistics...",
            progressHandler: progressHandler
        )

        let exporter = AIAnalysisPackageExporter()

        emitProgress(
            completedUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            message: "Exporting AI package...",
            progressHandler: progressHandler
        )
        let dataExportProgressHandler = progressMapper(
            startingUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            progressHandler: progressHandler
        )
        let paths = try await runCancellableDetached {
            try exporter.exportDataFiles(
                for: request.folderURL,
                metadata: folderAnalysisResult.exportMetadata,
                sourceFileURLs: folderAnalysisResult.fileURLs,
                statistics: generatedStatistics,
                paths: packagePaths,
                progressHandler: dataExportProgressHandler
            )
        }
        completedPipelineUnitCount += 2

        emitProgress(
            completedUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            message: "Generating contact sheet...",
            progressHandler: progressHandler
        )
        let contactSheetProgressUnitCount = Int64(contactSheetUnitCount(for: folderAnalysisResult.fileURLs.count))
        let contactSheetProgressHandler = progressMapper(
            startingUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            progressHandler: progressHandler
        )
        try await runCancellableDetached {
            try await exporter.exportContactSheet(
                folderURL: request.folderURL,
                sourceFileURLs: folderAnalysisResult.fileURLs,
                paths: paths,
                progressHandler: contactSheetProgressHandler
            )
        }
        try Task.checkCancellation()
        completedPipelineUnitCount += contactSheetProgressUnitCount

        let archiveProgressUnitCount = Int64(zipArchiveUnitCount(for: folderAnalysisResult.fileURLs.count))
        emitProgress(
            completedUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            message: "Archiving package...",
            progressHandler: progressHandler
        )
        let archiveProgressHandler = progressMapper(
            startingUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            allocatedUnitCount: archiveProgressUnitCount,
            progressHandler: progressHandler
        )
        _ = try await runCancellableDetached {
            try exporter.archivePackage(
                paths: paths,
                progressHandler: archiveProgressHandler
            )
        }
        try Task.checkCancellation()

        progressHandler?(AnalysisProgress(fractionCompleted: 1, message: "Package generated"))

        return AnalysisPipelineResult(
            paths: paths,
            statistics: generatedStatistics,
            supportedFileCount: fileURLs.count,
            analyzedPhotoCount: folderAnalysisResult.photos.count
        )
    }

    private func progressMapper(
        startingUnitCount: Int64,
        totalUnitCount: Int64,
        allocatedUnitCount: Int64? = nil,
        progressHandler: ProgressHandler?
    ) -> @Sendable (ProgressSnapshot) -> Void {
        let mapper = PipelineProgressMapper(
            startingUnitCount: startingUnitCount,
            totalUnitCount: totalUnitCount,
            allocatedUnitCount: allocatedUnitCount
        )

        return { @Sendable snapshot in
            progressHandler?(mapper.map(snapshot))
        }
    }

    private func emitProgress(
        completedUnitCount: Int64,
        totalUnitCount: Int64,
        message: String,
        progressHandler: ProgressHandler?
    ) {
        let mapper = PipelineProgressMapper(startingUnitCount: 0, totalUnitCount: totalUnitCount)
        progressHandler?(mapper.map(completedUnitCount: completedUnitCount, message: message))
    }

    private func totalPipelineUnitCount(for photoCount: Int) -> Int64 {
        let safePhotoCount = max(1, photoCount)
        return Int64(
            safePhotoCount +
            safePhotoCount +
            1 +
            2 +
            contactSheetUnitCount(for: safePhotoCount) +
            zipArchiveUnitCount(for: safePhotoCount)
        )
    }

    private func contactSheetUnitCount(for photoCount: Int) -> Int {
        let safePhotoCount = max(1, photoCount)
        let columns = ContactSheetLayout.columnCount(for: safePhotoCount)
        let itemsPerSheet = max(1, columns * ContactSheetLayout.maximumRowsPerSheet)
        let sheetCount = max(1, Int(ceil(Double(safePhotoCount) / Double(itemsPerSheet))))

        return safePhotoCount + sheetCount + 1
    }

    private func zipArchiveUnitCount(for photoCount: Int) -> Int {
        let safePhotoCount = max(1, photoCount)
        let columns = ContactSheetLayout.columnCount(for: safePhotoCount)
        let itemsPerSheet = max(1, columns * ContactSheetLayout.maximumRowsPerSheet)
        let sheetCount = max(1, Int(ceil(Double(safePhotoCount) / Double(itemsPerSheet))))
        let contactSheetAliasCount = sheetCount > 1 ? 1 : 0

        return 3 + sheetCount + contactSheetAliasCount
    }

    private func runCancellableDetached<T>(
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

nonisolated enum AnalysisPipelineError: Error {
    case noSupportedFiles
}
