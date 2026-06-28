//
//  AnalysisCoordinator.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 28/06/2026.
//

import Foundation
import Observation

/// Observable runtime state for the current analysis workflow.
@MainActor
@Observable
final class AnalysisCoordinator {
    /// The security-scoped folder URL selected by the user.
    var selectedFolderURL: URL?

    /// The currently selected analysis source.
    var selectedAnalysisSource: AnalysisSource?

    /// Selected PhotoKit asset identifiers used to build a manual Photos Library source.
    var selectedPhotoAssetIdentifiers = Set<String>()

    /// Last manually selected PhotoKit asset, used as the anchor for shift-selection.
    var lastSelectedPhotoAssetIdentifier: String?

    /// User-facing state for the selected dataset.
    var datasetState = DatasetUIState.initial

    /// User-facing state for the latest AI package export.
    var packageState = AIPackageUIState.initial

    /// The latest statistics computed from the analyzed photos.
    var statistics: PhotoStatistics?

    /// Contact sheet page browsing state for the latest package export.
    var contactSheetPreview = ContactSheetPreviewState()

    /// Whether a folder analysis is currently running.
    var isAnalyzing = false

    /// Whether the selected folder is currently being scanned for supported files.
    var isCountingSupportedFiles = false

    /// The current operation phase shown at the bottom of the interface.
    var analysisPhase: AnalysisPhase = .ready

    /// The current progress for the complete analysis pipeline.
    var analysisProgress: AnalysisProgress?

    /// Image assets available for manual PhotoKit-backed Photos selection.
    var photosAssets: [PhotosAssetSummary] = []

    /// Whether Photos assets are currently loading.
    var isLoadingPhotosAssets = false

    /// Asset loading error shown in the asset picker sheet.
    var photosAssetLoadingError: AppErrorInfo?

    /// Albums available for PhotoKit-backed Photos selection.
    var photosAlbums: [PhotosAlbumSummary] = []

    /// Whether Photos albums are currently loading.
    var isLoadingPhotosAlbums = false

    /// Album loading error shown in the album picker sheet.
    var photosAlbumLoadingError: AppErrorInfo?

    /// The currently running analysis task, if any.
    @ObservationIgnored var analysisTask: Task<Void, Never>?

    /// The currently running supported file count task, if any.
    @ObservationIgnored var supportedFileCountTask: Task<Void, Never>?

    /// Applies the shared UI state for a newly started analysis.
    func beginAnalysis(packagePaths: AIAnalysisPackagePaths, progressMessage: String) {
        isAnalyzing = true
        supportedFileCountTask?.cancel()
        supportedFileCountTask = nil
        isCountingSupportedFiles = false
        statistics = nil
        contactSheetPreview.reset()
        analysisProgress = AnalysisProgress(fractionCompleted: 0, message: progressMessage)
        datasetState.analysisStatus = .analyzing
        datasetState.analyzedPhotoCount = nil
        packageState = AIPackageUIState(
            status: .generating,
            packageURL: packagePaths.packageURL,
            metadataExists: false,
            statisticsExists: false,
            contactSheetExists: false,
            indexExists: false,
            archiveExists: false,
            error: nil
        )
    }

    /// Clears shared task state after an analysis exits.
    func finishAnalysis() {
        isAnalyzing = false
        analysisTask = nil
    }

    /// Applies the shared UI state for a completed analysis.
    func completeAnalysis(
        paths: AIAnalysisPackagePaths,
        statistics newStatistics: PhotoStatistics,
        supportedFileCount: Int,
        analyzedPhotoCount: Int,
        error: AppErrorInfo? = nil
    ) {
        statistics = newStatistics
        datasetState.supportedFileCount = supportedFileCount
        datasetState.analyzedPhotoCount = analyzedPhotoCount
        datasetState.analysisStatus = .completed
        packageState = AIPackageUIState(packageURL: paths.packageURL, error: error)
        analysisPhase = .completed
        contactSheetPreview.load(from: paths.packageURL)
    }

    /// Applies the shared UI state when a selected source contains no supported images.
    func handleNoSupportedFiles(status: AnalysisStatus) {
        datasetState.supportedFileCount = 0
        datasetState.analysisStatus = status
        packageState = .initial
        analysisPhase = .noSupportedFiles
        analysisProgress = nil
    }

    /// Applies the shared UI state for a cancelled analysis.
    func handleAnalysisCancellation(logMessage: String) {
        print(logMessage)
        statistics = nil
        contactSheetPreview.reset()
        datasetState.analysisStatus = .cancelled
        datasetState.analyzedPhotoCount = nil
        packageState = .initial
        analysisPhase = .cancelled
        analysisProgress = nil
    }

    /// Applies the shared UI state for an analysis or export failure.
    func handleAnalysisFailure(
        _ error: Error,
        packagePaths: AIAnalysisPackagePaths,
        logPrefix: String
    ) {
        let appError = AppErrorInfo.exportFailure(error)
        print("\(logPrefix): \(appError.debugDescription)")
        datasetState.analysisStatus = statistics == nil ? .failed : .completedWithExportError
        packageState = AIPackageUIState(packageURL: packagePaths.packageURL, error: appError)
        analysisPhase = statistics == nil ? .failed : .exportFailed
        analysisProgress = nil
    }

    /// Applies service progress to the dashboard state.
    func applyPipelineProgress(_ progress: AnalysisProgress) {
        analysisProgress = progress
        if let phase = progress.phase {
            analysisPhase = phase
        }
    }
}
