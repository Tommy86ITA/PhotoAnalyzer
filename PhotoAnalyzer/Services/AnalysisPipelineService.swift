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

    private let dependencies: AnalysisPipelineDependencies

    init(dependencies: AnalysisPipelineDependencies = .live) {
        self.dependencies = dependencies
    }

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
            phase: .scanningFiles,
            progressHandler: progressHandler
        )
        let scanningProgressUnitCount = Int64(max(1, expectedPhotoCount))
        let scanningProgressHandler = progressMapper(
            startingUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            phase: .scanningFiles,
            progressHandler: progressHandler
        )
        let fileURLs = try await runCancellableDetached {
            try Task.checkCancellation()
            return dependencies.scanImageFiles(
                request.folderURL,
                request.includeSubfolders,
                request.expectedSupportedFileCount,
                scanningProgressHandler
            )
        }
        try Task.checkCancellation()
        completedPipelineUnitCount += scanningProgressUnitCount
        emitProgress(
            completedUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            message: "Scanning files...",
            phase: .scanningFiles,
            progressHandler: progressHandler
        )

        guard !fileURLs.isEmpty else {
            throw AnalysisPipelineError.noSupportedFiles
        }

        let metadataProgressUnitCount = Int64(max(1, fileURLs.count))
        let metadataProgressHandler = progressMapper(
            startingUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            phase: .readingMetadata,
            progressHandler: progressHandler
        )
        let folderAnalysisResult = try await runCancellableDetached {
            try await dependencies.analyzeFiles(
                fileURLs,
                metadataProgressHandler
            )
        }
        try Task.checkCancellation()
        completedPipelineUnitCount += metadataProgressUnitCount
        emitProgress(
            completedUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            message: "Reading metadata...",
            phase: .readingMetadata,
            progressHandler: progressHandler
        )

        emitProgress(
            completedUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            message: "Generating statistics...",
            phase: .generatingStatistics,
            progressHandler: progressHandler
        )
        let generatedStatistics = try await runCancellableDetached {
            try Task.checkCancellation()
            return dependencies.buildStatistics(folderAnalysisResult.photos)
        }
        try Task.checkCancellation()
        completedPipelineUnitCount += 1
        emitProgress(
            completedUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            message: "Generating statistics...",
            phase: .generatingStatistics,
            progressHandler: progressHandler
        )

        emitProgress(
            completedUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            message: "Exporting AI package...",
            phase: .exportingAIPackage,
            progressHandler: progressHandler
        )
        let dataExportProgressHandler = progressMapper(
            startingUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            phase: .exportingAIPackage,
            progressHandler: progressHandler
        )
        let paths = try await runCancellableDetached {
            try dependencies.exportDataFiles(
                request.folderURL,
                folderAnalysisResult.exportMetadata,
                folderAnalysisResult.fileURLs,
                generatedStatistics,
                packagePaths,
                dataExportProgressHandler
            )
        }
        completedPipelineUnitCount += 2

        emitProgress(
            completedUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            message: "Generating contact sheet...",
            phase: .generatingContactSheet,
            progressHandler: progressHandler
        )
        let contactSheetProgressUnitCount = Int64(contactSheetUnitCount(for: folderAnalysisResult.fileURLs.count))
        let contactSheetProgressHandler = progressMapper(
            startingUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            phase: .generatingContactSheet,
            progressHandler: progressHandler
        )
        try await runCancellableDetached {
            try await dependencies.exportContactSheet(
                request.folderURL,
                folderAnalysisResult.fileURLs,
                paths,
                contactSheetProgressHandler
            )
        }
        try Task.checkCancellation()
        completedPipelineUnitCount += contactSheetProgressUnitCount

        let archiveProgressUnitCount = Int64(zipArchiveUnitCount(for: folderAnalysisResult.fileURLs.count))
        emitProgress(
            completedUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            message: "Archiving package...",
            phase: .archivingPackage,
            progressHandler: progressHandler
        )
        let archiveProgressHandler = progressMapper(
            startingUnitCount: completedPipelineUnitCount,
            totalUnitCount: pipelineTotalUnitCount,
            allocatedUnitCount: archiveProgressUnitCount,
            phase: .archivingPackage,
            progressHandler: progressHandler
        )
        _ = try await runCancellableDetached {
            try dependencies.archivePackage(
                paths,
                archiveProgressHandler
            )
        }
        try Task.checkCancellation()

        progressHandler?(AnalysisProgress(fractionCompleted: 1, message: "Package generated", phase: .completed))

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
        phase: AnalysisPhase,
        progressHandler: ProgressHandler?
    ) -> @Sendable (ProgressSnapshot) -> Void {
        let mapper = PipelineProgressMapper(
            startingUnitCount: startingUnitCount,
            totalUnitCount: totalUnitCount,
            allocatedUnitCount: allocatedUnitCount,
            phase: phase
        )

        return { @Sendable snapshot in
            progressHandler?(mapper.map(snapshot))
        }
    }

    private func emitProgress(
        completedUnitCount: Int64,
        totalUnitCount: Int64,
        message: String,
        phase: AnalysisPhase,
        progressHandler: ProgressHandler?
    ) {
        let mapper = PipelineProgressMapper(
            startingUnitCount: 0,
            totalUnitCount: totalUnitCount,
            phase: phase
        )
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
