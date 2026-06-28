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
    @ObservationIgnored private var analysisTask: Task<Void, Never>?

    /// The currently running supported file count task, if any.
    @ObservationIgnored private var supportedFileCountTask: Task<Void, Never>?

    /// Stores a folder source and starts counting supported files.
    func selectFolder(_ url: URL, includeSubfolders: Bool) {
        selectedFolderURL = url
        selectedAnalysisSource = .folder(FolderAnalysisSource(
            folderURL: url,
            includeSubfolders: includeSubfolders
        ))
        selectedPhotoAssetIdentifiers = []
        lastSelectedPhotoAssetIdentifier = nil
        resetGeneratedPackageState()

        datasetState = DatasetUIState(
            folderURL: url,
            supportedFileCount: nil,
            analyzedPhotoCount: nil,
            analysisStatus: .folderSelected
        )
        startSupportedFileCount(for: url, includeSubfolders: includeSubfolders)
    }

    /// Loads PhotoKit assets for the manual Photos picker sheet.
    func loadPhotosAssets() {
        guard !isLoadingPhotosAssets else {
            return
        }

        isLoadingPhotosAssets = true
        photosAssetLoadingError = nil

        Task {
            defer {
                isLoadingPhotosAssets = false
            }

            do {
                let assets = try await PhotosLibraryAssetBrowserService().fetchImageAssets()
                guard !Task.isCancelled else {
                    return
                }

                photosAssets = assets
                photosAssetLoadingError = nil
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                photosAssets = []
                photosAssetLoadingError = AppErrorInfo.exportFailure(error)
            }
        }
    }

    /// Toggles a PhotoKit asset in the manual Photos selection sheet.
    func toggleSelectedPhotoAsset(
        _ asset: PhotosAssetSummary,
        in orderedAssets: [PhotosAssetSummary],
        isCommandSelection: Bool,
        isRangeSelection: Bool
    ) {
        if isRangeSelection {
            selectPhotoAssetRange(
                through: asset,
                in: orderedAssets,
                extendsExistingSelection: isCommandSelection
            )
        } else if isCommandSelection {
            togglePhotoAsset(asset)
        } else {
            selectedPhotoAssetIdentifiers = [asset.localIdentifier]
            lastSelectedPhotoAssetIdentifier = asset.localIdentifier
        }
    }

    /// Toggles an asset while preserving the rest of the selection.
    private func togglePhotoAsset(_ asset: PhotosAssetSummary) {
        if selectedPhotoAssetIdentifiers.contains(asset.localIdentifier) {
            selectedPhotoAssetIdentifiers.remove(asset.localIdentifier)
        } else {
            selectedPhotoAssetIdentifiers.insert(asset.localIdentifier)
            lastSelectedPhotoAssetIdentifier = asset.localIdentifier
        }
    }

    /// Selects the provided PhotoKit assets in the manual Photos selection sheet.
    func selectPhotoAssets(_ assets: [PhotosAssetSummary]) {
        selectedPhotoAssetIdentifiers = Set(assets.map(\.localIdentifier))
        lastSelectedPhotoAssetIdentifier = assets.last?.localIdentifier
    }

    /// Clears the manual PhotoKit asset selection.
    func clearSelectedPhotoAssets() {
        selectedPhotoAssetIdentifiers = []
        lastSelectedPhotoAssetIdentifier = nil
    }

    /// Stores manually selected PhotoKit assets as the active Photos source.
    @discardableResult
    func confirmSelectedPhotosAssets(
        representation: PhotosAssetRepresentation,
        networkAccessPolicy: PhotosNetworkAccessPolicy
    ) -> Bool {
        guard !selectedPhotoAssetIdentifiers.isEmpty else {
            return false
        }

        let identifiers = photosAssets
            .map(\.localIdentifier)
            .filter { selectedPhotoAssetIdentifiers.contains($0) }

        selectedAnalysisSource = .photosLibrary(PhotosSelection(
            mode: .assets(localIdentifiers: identifiers),
            representation: representation,
            networkAccessPolicy: networkAccessPolicy
        ))
        selectedFolderURL = nil
        supportedFileCountTask?.cancel()
        supportedFileCountTask = nil
        isCountingSupportedFiles = false
        resetGeneratedPackageState()
        datasetState = DatasetUIState(
            folderURL: nil,
            supportedFileCount: identifiers.count,
            analyzedPhotoCount: nil,
            analysisStatus: .sourceSelected
        )
        analysisPhase = .ready
        return true
    }

    /// Loads PhotoKit albums for the album picker sheet.
    func loadPhotosAlbums() {
        guard !isLoadingPhotosAlbums else {
            return
        }

        isLoadingPhotosAlbums = true
        photosAlbumLoadingError = nil

        Task {
            defer {
                isLoadingPhotosAlbums = false
            }

            do {
                let albums = try await PhotosLibraryAlbumService().fetchAlbums()
                guard !Task.isCancelled else {
                    return
                }

                photosAlbums = albums
                photosAlbumLoadingError = nil
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                photosAlbums = []
                photosAlbumLoadingError = AppErrorInfo.exportFailure(error)
            }
        }
    }

    /// Stores a PhotoKit-backed Photos Library source and starts counting image assets.
    func applyPhotoKitSelection(
        _ selection: PhotosSelection,
        knownAssetCount: Int? = nil
    ) {
        selectedFolderURL = nil
        selectedPhotoAssetIdentifiers = []
        lastSelectedPhotoAssetIdentifier = nil
        supportedFileCountTask?.cancel()
        supportedFileCountTask = nil
        isCountingSupportedFiles = false
        resetGeneratedPackageState()

        selectedAnalysisSource = .photosLibrary(selection)
        datasetState = DatasetUIState(
            folderURL: nil,
            supportedFileCount: knownAssetCount,
            analyzedPhotoCount: nil,
            analysisStatus: .sourceSelected
        )
        analysisPhase = knownAssetCount == 0 ? .noSupportedFiles : .ready

        if knownAssetCount == nil {
            startPhotosSelectionCount(selection)
        }
    }

    /// Applies current Photos analysis preferences to the active Photos source.
    func updateSelectedPhotosPolicy(
        representation: PhotosAssetRepresentation,
        networkAccessPolicy: PhotosNetworkAccessPolicy
    ) {
        guard case .photosLibrary(let selection) = selectedAnalysisSource else {
            return
        }

        selectedAnalysisSource = .photosLibrary(PhotosSelection(
            mode: selection.mode,
            representation: representation,
            networkAccessPolicy: networkAccessPolicy
        ))
    }

    /// Recounts supported files after scan options change.
    func updateSupportedFileCountForSelectedFolder(includeSubfolders: Bool) {
        guard !isAnalyzing,
              !isCountingSupportedFiles,
              let selectedFolderURL else {
            return
        }

        selectedAnalysisSource = .folder(FolderAnalysisSource(
            folderURL: selectedFolderURL,
            includeSubfolders: includeSubfolders
        ))

        statistics = nil
        packageState = .initial
        contactSheetPreview.reset()
        analysisProgress = nil
        datasetState.supportedFileCount = nil
        datasetState.analyzedPhotoCount = nil
        datasetState.analysisStatus = .folderSelected
        startSupportedFileCount(
            for: selectedFolderURL,
            includeSubfolders: includeSubfolders
        )
    }

    /// Clears package-specific state after output destination changes.
    func resetGeneratedPackageState() {
        statistics = nil
        packageState = .initial
        contactSheetPreview.reset()
        analysisProgress = nil
    }

    /// Starts analysis for the selected source.
    func analyzeSelectedSource(
        outputFolderURL: URL,
        includeSubfolders: Bool,
        metadataCacheMaximumSizeMB: Int,
        exportDiagnosticReports: Bool
    ) {
        guard !isAnalyzing, !isCountingSupportedFiles else {
            return
        }

        guard let selectedAnalysisSource else {
            analysisPhase = .noFolderSelected
            return
        }

        guard (datasetState.supportedFileCount ?? 0) > 0 else {
            analysisPhase = .noSupportedFiles
            return
        }

        switch selectedAnalysisSource {
        case .folder(let source):
            let task = Task {
                await analyzeSelectedFolderFiles(
                    in: source.folderURL,
                    outputFolderURL: outputFolderURL,
                    includeSubfolders: includeSubfolders,
                    metadataCacheMaximumSizeMB: metadataCacheMaximumSizeMB,
                    exportDiagnosticReports: exportDiagnosticReports
                )
            }
            analysisTask = task
        case .photosLibrary(let selection):
            let task = Task {
                await analyzePhotoKitSelection(
                    selection,
                    outputFolderURL: outputFolderURL,
                    metadataCacheMaximumSizeMB: metadataCacheMaximumSizeMB,
                    exportDiagnosticReports: exportDiagnosticReports
                )
            }
            analysisTask = task
        }
    }

    /// Cancels the currently running analysis, if any.
    func cancelAnalysis() {
        analysisTask?.cancel()
    }

    /// Applies the shared UI state for a newly started analysis.
    private func beginAnalysis(packagePaths: AIAnalysisPackagePaths, progressMessage: String) {
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
    private func finishAnalysis() {
        isAnalyzing = false
        analysisTask = nil
    }

    /// Applies the shared UI state for a completed analysis.
    private func completeAnalysis(
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
    private func handleNoSupportedFiles(status: AnalysisStatus) {
        datasetState.supportedFileCount = 0
        datasetState.analysisStatus = status
        packageState = .initial
        analysisPhase = .noSupportedFiles
        analysisProgress = nil
    }

    /// Applies the shared UI state for a cancelled analysis.
    private func handleAnalysisCancellation(logMessage: String) {
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
    private func handleAnalysisFailure(
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
    private func applyPipelineProgress(_ progress: AnalysisProgress) {
        analysisProgress = progress
        if let phase = progress.phase {
            analysisPhase = phase
        }
    }

    /// Runs folder analysis and package export for the selected folder.
    /// - Parameter folderURL: The folder URL selected by the user.
    private func analyzeSelectedFolderFiles(
        in folderURL: URL,
        outputFolderURL: URL,
        includeSubfolders: Bool,
        metadataCacheMaximumSizeMB: Int,
        exportDiagnosticReports: Bool
    ) async {
        guard !isAnalyzing else {
            return
        }

        let expectedSupportedFileCount = datasetState.supportedFileCount
        let packagePaths = AIAnalysisPackagePaths(
            datasetFolderURL: folderURL,
            outputFolderURL: outputFolderURL
        )

        beginAnalysis(packagePaths: packagePaths, progressMessage: "Starting analysis...")
        defer {
            finishAnalysis()
        }

        do {
            let result = try await AnalysisPipelineService().run(
                request: AnalysisPipelineRequest(
                    folderURL: folderURL,
                    outputFolderURL: outputFolderURL,
                    includeSubfolders: includeSubfolders,
                    expectedSupportedFileCount: expectedSupportedFileCount,
                    metadataCacheMaximumSizeMB: metadataCacheMaximumSizeMB,
                    exportDiagnosticReports: exportDiagnosticReports
                ),
                progressHandler: { progress in
                    Task { @MainActor in
                        self.applyPipelineProgress(progress)
                    }
                }
            )

            completeAnalysis(
                paths: result.paths,
                statistics: result.statistics,
                supportedFileCount: result.supportedFileCount,
                analyzedPhotoCount: result.analyzedPhotoCount
            )
        } catch AnalysisPipelineError.noSupportedFiles {
            handleNoSupportedFiles(status: .folderSelected)
        } catch is CancellationError {
            handleAnalysisCancellation(logMessage: "Folder analysis cancelled.")
        } catch {
            handleAnalysisFailure(error, packagePaths: packagePaths, logPrefix: "AI package export failed")
        }
    }

    /// Materializes a PhotoKit-backed Photos Library selection and runs the file-based pipeline.
    private func analyzePhotoKitSelection(
        _ selection: PhotosSelection,
        outputFolderURL: URL,
        metadataCacheMaximumSizeMB: Int,
        exportDiagnosticReports: Bool
    ) async {
        guard !isAnalyzing else {
            return
        }

        let datasetName = selection.displayName
        let packagePaths = AIAnalysisPackagePaths(
            datasetName: datasetName,
            datasetFolderURL: FileManager.default.temporaryDirectory,
            outputFolderURL: outputFolderURL
        )

        beginAnalysis(packagePaths: packagePaths, progressMessage: "Preparing Photos assets...")
        defer {
            finishAnalysis()
        }

        do {
            let result = try await PhotosAnalysisPipelineService().run(
                request: PhotosAnalysisPipelineRequest(
                    selection: selection,
                    outputFolderURL: outputFolderURL,
                    datasetName: datasetName,
                    metadataCacheMaximumSizeMB: metadataCacheMaximumSizeMB,
                    exportDiagnosticReports: exportDiagnosticReports
                ),
                progressHandler: { progress in
                    Task { @MainActor in
                        self.applyPipelineProgress(progress)
                    }
                }
            )

            completeAnalysis(
                paths: result.paths,
                statistics: result.statistics,
                supportedFileCount: result.supportedFileCount,
                analyzedPhotoCount: result.analyzedPhotoCount,
                error: AppErrorInfo.photosSkippedAssets(result.skippedAssets)
            )
        } catch AnalysisPipelineError.noSupportedFiles {
            handleNoSupportedFiles(status: .sourceSelected)
        } catch is CancellationError {
            handleAnalysisCancellation(logMessage: "Photos analysis cancelled.")
        } catch {
            handleAnalysisFailure(error, packagePaths: packagePaths, logPrefix: "Photos package export failed")
        }
    }

    /// Selects a contiguous range from the last selected asset to the current asset.
    private func selectPhotoAssetRange(
        through asset: PhotosAssetSummary,
        in orderedAssets: [PhotosAssetSummary],
        extendsExistingSelection: Bool
    ) {
        guard let anchorIdentifier = lastSelectedPhotoAssetIdentifier,
              let anchorIndex = orderedAssets.firstIndex(where: { $0.localIdentifier == anchorIdentifier }),
              let currentIndex = orderedAssets.firstIndex(of: asset) else {
            selectedPhotoAssetIdentifiers = [asset.localIdentifier]
            lastSelectedPhotoAssetIdentifier = asset.localIdentifier
            return
        }

        let bounds = min(anchorIndex, currentIndex)...max(anchorIndex, currentIndex)
        let rangeIdentifiers = Set(orderedAssets[bounds].map(\.localIdentifier))

        if extendsExistingSelection {
            selectedPhotoAssetIdentifiers.formUnion(rangeIdentifiers)
        } else {
            selectedPhotoAssetIdentifiers = rangeIdentifiers
        }
    }

    /// Starts an asynchronous image asset count for a PhotoKit-backed Photos selection.
    private func startPhotosSelectionCount(_ selection: PhotosSelection) {
        supportedFileCountTask?.cancel()
        isCountingSupportedFiles = true
        analysisPhase = .scanningFiles

        let task = Task {
            do {
                let count = try await PhotosLibraryCountService().countImageAssets(in: selection)
                guard !Task.isCancelled else {
                    return
                }

                datasetState.supportedFileCount = count
                datasetState.analyzedPhotoCount = nil
                datasetState.analysisStatus = .sourceSelected
                analysisPhase = count > 0 ? .ready : .noSupportedFiles
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                datasetState.supportedFileCount = nil
                datasetState.analyzedPhotoCount = nil
                datasetState.analysisStatus = .failed
                packageState = AIPackageUIState(
                    status: .failed,
                    packageURL: nil,
                    metadataExists: false,
                    statisticsExists: false,
                    contactSheetExists: false,
                    indexExists: false,
                    archiveExists: false,
                    error: AppErrorInfo.exportFailure(error)
                )
                analysisPhase = .failed
            }

            isCountingSupportedFiles = false
            supportedFileCountTask = nil
        }
        supportedFileCountTask = task
    }

    /// Starts an asynchronous supported file count for the selected folder.
    /// - Parameters:
    ///   - folderURL: The selected folder URL.
    ///   - includeSubfolders: Whether subfolders should be scanned recursively.
    private func startSupportedFileCount(for folderURL: URL, includeSubfolders: Bool) {
        supportedFileCountTask?.cancel()
        isCountingSupportedFiles = true
        analysisPhase = .scanningFiles

        let task = Task {
            let countTask = Task<Int, Never>.detached(priority: .utility) {
                SupportedFileCountService()
                    .countSupportedFiles(in: folderURL, includeSubfolders: includeSubfolders)
            }
            let fileCount = await withTaskCancellationHandler {
                await countTask.value
            } onCancel: {
                countTask.cancel()
            }

            guard !Task.isCancelled else {
                return
            }

            datasetState.supportedFileCount = fileCount
            datasetState.analyzedPhotoCount = nil
            datasetState.analysisStatus = .folderSelected
            analysisPhase = fileCount > 0 ? .ready : .noSupportedFiles
            isCountingSupportedFiles = false
            supportedFileCountTask = nil
        }
        supportedFileCountTask = task
    }
}
