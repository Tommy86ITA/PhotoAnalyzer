//
//  ContentView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 15/06/2026.
//

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

/// Main interface for the PhotoAnalyzer macOS application.
struct ContentView: View {
    private enum Layout {
        static let contentSpacing: CGFloat = 16
        static let contentPadding: CGFloat = 26
        static let mainColumnSpacing: CGFloat = 12
        static let dashboardSpacing: CGFloat = 18
        static let windowWidth: CGFloat = 1200
        static let windowDefaultHeight: CGFloat = 800
        static let windowMinimumHeight: CGFloat = 820
    }

    /// Runtime state and task coordination for the analysis workflow.
    @State private var coordinator = AnalysisCoordinator()

    /// Security-scoped output folder for generated AI packages.
    @State private var selectedOutputFolderURL = DefaultOutputFolderProvider.defaultOutputFolderURL()

    /// Whether selected dataset subfolders should be scanned.
    @AppStorage("analysis.includeSubfolders") private var includeSubfolders = false

    /// Whether Photos Library analysis should use unmodified original assets.
    @AppStorage("photos.useUnmodifiedOriginals") private var useUnmodifiedPhotosOriginals = true

    /// Whether Photos Library analysis may download missing iCloud originals.
    @AppStorage("photos.downloadMissingOriginals") private var downloadMissingPhotosOriginals = false

    /// Maximum disk space for cached ExifTool metadata.
    @AppStorage("metadataCache.maximumSizeMB") private var metadataCacheMaximumSizeMB = MetadataCacheSizeLimit.mb512.rawValue

    /// Whether package exports should include optional quality and diagnostic JSON reports.
    @AppStorage("analysis.exportDiagnosticReports") private var exportDiagnosticReports = false

    /// Security-scoped bookmark for the user-selected output folder.
    @AppStorage("outputFolder.bookmark") private var outputFolderBookmarkData = Data()

    /// Presenter that owns the dedicated contact sheet viewer window.
    @State private var contactSheetViewerPresenter = ContactSheetViewerPresenter()

    /// Current on-disk metadata cache usage shown in Settings.
    @State private var metadataCacheUsage = MetadataCacheUsage(byteCount: 0, entryCount: 0)

    /// Whether the dedicated settings sheet is visible.
    @State private var isShowingSettings = false

    /// Whether the PhotoKit album picker sheet is visible.
    @State private var isShowingPhotosAlbumPicker = false

    /// Whether the PhotoKit asset picker sheet is visible.
    @State private var isShowingPhotosAssetPicker = false

    /// The view hierarchy for the PhotoAnalyzer interface.
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Layout.contentSpacing) {
                AppHeaderView()

                DatasetActionView(
                    datasetState: coordinator.datasetState,
                    sourceIconName: sourceIconName,
                    sourceText: sourceText,
                    sourcePath: sourcePath,
                    isSourcePlaceholder: coordinator.selectedAnalysisSource == nil,
                    isFolderSource: isFolderSource,
                    canAnalyze: canAnalyzeSelectedSource,
                    isAnalyzing: coordinator.isAnalyzing,
                    isCountingSupportedFiles: coordinator.isCountingSupportedFiles,
                    useUnmodifiedPhotosOriginals: useUnmodifiedPhotosOriginals,
                    downloadMissingPhotosOriginals: downloadMissingPhotosOriginals,
                    includeSubfolders: $includeSubfolders,
                    selectFolder: selectFolder,
                    selectPhotos: choosePhotosAssets,
                    choosePhotosAlbum: choosePhotosAlbum,
                    useEntirePhotosLibrary: useEntirePhotosLibrary,
                    openSettings: openSettings,
                    analyze: analyzeSelectedSource,
                    cancelAnalysis: cancelAnalysis
                )

                StatusFooterView(
                    statusMessage: coordinator.analysisPhase.displayText,
                    isBusy: coordinator.isAnalyzing || coordinator.isCountingSupportedFiles,
                    progress: footerProgress
                )

                GeometryReader { proxy in
                    HStack(alignment: .top, spacing: Layout.dashboardSpacing) {
                        VStack(spacing: Layout.mainColumnSpacing) {
                            AIPackageCardView(
                                packageState: coordinator.packageState,
                                isAnalyzing: coordinator.isAnalyzing,
                                canOpenContactSheet: coordinator.contactSheetPreview.canOpenViewer,
                                openPackage: openPackage,
                                revealArchive: revealArchive,
                                openContactSheet: openContactSheetViewer
                            )

                            DatasetOverviewView(statistics: coordinator.statistics)
                        }
                        .frame(maxWidth: .infinity, maxHeight: proxy.size.height, alignment: .top)

                        ContactSheetPreviewView(
                            image: coordinator.contactSheetPreview.image,
                            packageStatus: coordinator.packageState.status,
                            currentPageIndex: coordinator.contactSheetPreview.currentPageIndex,
                            pageCount: coordinator.contactSheetPreview.pageCount,
                            previousPage: { coordinator.contactSheetPreview.showPreviousPage() },
                            nextPage: { coordinator.contactSheetPreview.showNextPage() },
                            openViewer: openContactSheetViewer
                        )
                        .frame(maxWidth: .infinity, maxHeight: proxy.size.height, alignment: .top)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                }
                .frame(maxHeight: .infinity, alignment: .top)

                Spacer(minLength: 0)
            }
            .padding(Layout.contentPadding)
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: Layout.windowWidth, minHeight: Layout.windowMinimumHeight, alignment: .topLeading)
        .background(
            WindowPlacementView(
                size: CGSize(width: Layout.windowWidth, height: Layout.windowDefaultHeight),
                minimumSize: CGSize(width: Layout.windowWidth, height: Layout.windowMinimumHeight)
            )
            .frame(width: 1, height: 1)
            .accessibilityHidden(true)
        )
        .onChange(of: includeSubfolders) { _, _ in
            updateSupportedFileCountForSelectedFolder()
        }
        .onChange(of: useUnmodifiedPhotosOriginals) { _, _ in
            updateSelectedPhotosPolicy()
        }
        .onChange(of: downloadMissingPhotosOriginals) { _, _ in
            updateSelectedPhotosPolicy()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                useUnmodifiedPhotosOriginals: $useUnmodifiedPhotosOriginals,
                downloadMissingPhotosOriginals: $downloadMissingPhotosOriginals,
                metadataCacheMaximumSizeMB: $metadataCacheMaximumSizeMB,
                exportDiagnosticReports: $exportDiagnosticReports,
                metadataCacheUsage: metadataCacheUsage,
                outputFolderURL: selectedOutputFolderURL,
                canEditSettings: !coordinator.isAnalyzing && !coordinator.isCountingSupportedFiles,
                selectOutputFolder: selectOutputFolder,
                refreshMetadataCacheUsage: refreshMetadataCacheUsage,
                clearMetadataCache: clearMetadataCache,
                dismiss: { isShowingSettings = false }
            )
        }
        .sheet(isPresented: $isShowingPhotosAlbumPicker) {
            PhotosAlbumPickerView(
                albums: coordinator.photosAlbums,
                isLoading: coordinator.isLoadingPhotosAlbums,
                error: coordinator.photosAlbumLoadingError,
                selectAlbum: selectPhotosAlbum,
                refresh: loadPhotosAlbums,
                dismiss: { isShowingPhotosAlbumPicker = false }
            )
        }
        .sheet(isPresented: $isShowingPhotosAssetPicker) {
            PhotosAssetPickerView(
                assets: coordinator.photosAssets,
                isLoading: coordinator.isLoadingPhotosAssets,
                error: coordinator.photosAssetLoadingError,
                selectedAssetIdentifiers: coordinator.selectedPhotoAssetIdentifiers,
                toggleAsset: toggleSelectedPhotoAsset,
                selectAssets: selectPhotoAssets,
                clearSelection: clearSelectedPhotoAssets,
                confirmSelection: confirmSelectedPhotosAssets,
                refresh: loadPhotosAssets,
                dismiss: { isShowingPhotosAssetPicker = false }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPhotoAnalyzerSettings)) { _ in
            openSettings()
        }
        .onAppear {
            configureOutputFolder()
        }
    }

    private var sourceIconName: String {
        switch coordinator.selectedAnalysisSource {
        case .folder:
            "folder.fill"
        case .photosLibrary:
            "photo.on.rectangle.angled"
        case nil:
            "folder"
        }
    }

    private var sourceText: String {
        coordinator.selectedAnalysisSource?.displayName ?? "No source selected"
    }

    private var sourcePath: String? {
        guard case .folder(let source) = coordinator.selectedAnalysisSource else {
            return nil
        }
        return source.folderURL.path
    }

    private var canAnalyzeSelectedSource: Bool {
        guard coordinator.selectedAnalysisSource != nil else {
            return false
        }
        return (coordinator.datasetState.supportedFileCount ?? 0) > 0
    }

    private var isFolderSource: Bool {
        if case .folder = coordinator.selectedAnalysisSource {
            return true
        }

        return false
    }

    private var photosAssetRepresentation: PhotosAssetRepresentation {
        useUnmodifiedPhotosOriginals ? .original : .current
    }

    private var photosNetworkAccessPolicy: PhotosNetworkAccessPolicy {
        downloadMissingPhotosOriginals ? .downloadMissingOriginals : .localOnly
    }

    private var footerProgress: AnalysisProgress? {
        if let analysisProgress = coordinator.analysisProgress {
            return analysisProgress
        }

        guard coordinator.isAnalyzing || coordinator.isCountingSupportedFiles else {
            return nil
        }

        return AnalysisProgress(fractionCompleted: 0, message: coordinator.analysisPhase.displayText)
    }

    /// Opens a folder picker and stores the selected folder path.
    private func selectFolder() {
        guard !coordinator.isAnalyzing, !coordinator.isCountingSupportedFiles else {
            return
        }

        guard let url = FolderSelectionPanel.selectFolder() else {
            return
        }

        coordinator.selectedFolderURL = url
        coordinator.selectedAnalysisSource = .folder(FolderAnalysisSource(
            folderURL: url,
            includeSubfolders: includeSubfolders
        ))
        coordinator.selectedPhotoAssetIdentifiers = []
        coordinator.lastSelectedPhotoAssetIdentifier = nil
        coordinator.statistics = nil
        coordinator.packageState = .initial
        coordinator.contactSheetPreview.reset()
        coordinator.analysisProgress = nil

        coordinator.datasetState = DatasetUIState(
            folderURL: url,
            supportedFileCount: nil,
            analyzedPhotoCount: nil,
            analysisStatus: .folderSelected
        )
        startSupportedFileCount(for: url, includeSubfolders: includeSubfolders)
    }

    /// Opens the PhotoKit asset picker.
    private func choosePhotosAssets() {
        guard !coordinator.isAnalyzing, !coordinator.isCountingSupportedFiles else {
            return
        }

        isShowingPhotosAssetPicker = true
        loadPhotosAssets()
    }

    /// Loads PhotoKit assets for the manual Photos picker sheet.
    private func loadPhotosAssets() {
        guard !coordinator.isLoadingPhotosAssets else {
            return
        }

        coordinator.isLoadingPhotosAssets = true
        coordinator.photosAssetLoadingError = nil

        Task {
            defer {
                coordinator.isLoadingPhotosAssets = false
            }

            do {
                let assets = try await PhotosLibraryAssetBrowserService().fetchImageAssets()
                guard !Task.isCancelled else {
                    return
                }

                coordinator.photosAssets = assets
                coordinator.photosAssetLoadingError = nil
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                coordinator.photosAssets = []
                coordinator.photosAssetLoadingError = AppErrorInfo.exportFailure(error)
            }
        }
    }

    /// Toggles a PhotoKit asset in the manual Photos selection sheet.
    private func toggleSelectedPhotoAsset(
        _ asset: PhotosAssetSummary,
        in orderedAssets: [PhotosAssetSummary]
    ) {
        #if canImport(AppKit)
        let modifierFlags = NSEvent.modifierFlags
        let isCommandSelection = modifierFlags.contains(.command)
        let isRangeSelection = modifierFlags.contains(.shift)
        #else
        let isCommandSelection = false
        let isRangeSelection = false
        #endif

        if isRangeSelection {
            selectPhotoAssetRange(
                through: asset,
                in: orderedAssets,
                extendsExistingSelection: isCommandSelection
            )
        } else if isCommandSelection {
            togglePhotoAsset(asset)
        } else {
            coordinator.selectedPhotoAssetIdentifiers = [asset.localIdentifier]
            coordinator.lastSelectedPhotoAssetIdentifier = asset.localIdentifier
        }
    }

    /// Toggles an asset while preserving the rest of the selection.
    private func togglePhotoAsset(_ asset: PhotosAssetSummary) {
        if coordinator.selectedPhotoAssetIdentifiers.contains(asset.localIdentifier) {
            coordinator.selectedPhotoAssetIdentifiers.remove(asset.localIdentifier)
        } else {
            coordinator.selectedPhotoAssetIdentifiers.insert(asset.localIdentifier)
            coordinator.lastSelectedPhotoAssetIdentifier = asset.localIdentifier
        }
    }

    /// Selects a contiguous range from the last selected asset to the current asset.
    private func selectPhotoAssetRange(
        through asset: PhotosAssetSummary,
        in orderedAssets: [PhotosAssetSummary],
        extendsExistingSelection: Bool
    ) {
        guard let anchorIdentifier = coordinator.lastSelectedPhotoAssetIdentifier,
              let anchorIndex = orderedAssets.firstIndex(where: { $0.localIdentifier == anchorIdentifier }),
              let currentIndex = orderedAssets.firstIndex(of: asset) else {
            coordinator.selectedPhotoAssetIdentifiers = [asset.localIdentifier]
            coordinator.lastSelectedPhotoAssetIdentifier = asset.localIdentifier
            return
        }

        let bounds = min(anchorIndex, currentIndex)...max(anchorIndex, currentIndex)
        let rangeIdentifiers = Set(orderedAssets[bounds].map(\.localIdentifier))

        if extendsExistingSelection {
            coordinator.selectedPhotoAssetIdentifiers.formUnion(rangeIdentifiers)
        } else {
            coordinator.selectedPhotoAssetIdentifiers = rangeIdentifiers
        }
    }

    /// Selects the provided PhotoKit assets in the manual Photos selection sheet.
    private func selectPhotoAssets(_ assets: [PhotosAssetSummary]) {
        coordinator.selectedPhotoAssetIdentifiers = Set(assets.map(\.localIdentifier))
        coordinator.lastSelectedPhotoAssetIdentifier = assets.last?.localIdentifier
    }

    /// Clears the manual PhotoKit asset selection.
    private func clearSelectedPhotoAssets() {
        coordinator.selectedPhotoAssetIdentifiers = []
        coordinator.lastSelectedPhotoAssetIdentifier = nil
    }

    /// Stores manually selected PhotoKit assets as the active Photos source.
    private func confirmSelectedPhotosAssets() {
        guard !coordinator.selectedPhotoAssetIdentifiers.isEmpty else {
            return
        }

        let identifiers = coordinator.photosAssets
            .map(\.localIdentifier)
            .filter { coordinator.selectedPhotoAssetIdentifiers.contains($0) }

        coordinator.selectedAnalysisSource = .photosLibrary(PhotosSelection(
            mode: .assets(localIdentifiers: identifiers),
            representation: photosAssetRepresentation,
            networkAccessPolicy: photosNetworkAccessPolicy
        ))
        coordinator.selectedFolderURL = nil
        coordinator.supportedFileCountTask?.cancel()
        coordinator.supportedFileCountTask = nil
        coordinator.isCountingSupportedFiles = false
        coordinator.statistics = nil
        coordinator.packageState = .initial
        coordinator.contactSheetPreview.reset()
        coordinator.analysisProgress = nil
        coordinator.datasetState = DatasetUIState(
            folderURL: nil,
            supportedFileCount: identifiers.count,
            analyzedPhotoCount: nil,
            analysisStatus: .sourceSelected
        )
        coordinator.analysisPhase = .ready
        isShowingPhotosAssetPicker = false
    }

    /// Opens the PhotoKit album picker.
    private func choosePhotosAlbum() {
        guard !coordinator.isAnalyzing, !coordinator.isCountingSupportedFiles else {
            return
        }

        isShowingPhotosAlbumPicker = true
        loadPhotosAlbums()
    }

    /// Uses the complete Photos Library as the active PhotoKit-backed source.
    private func useEntirePhotosLibrary() {
        guard !coordinator.isAnalyzing, !coordinator.isCountingSupportedFiles else {
            return
        }

        let selection = PhotosSelection(
            mode: .library,
            representation: photosAssetRepresentation,
            networkAccessPolicy: photosNetworkAccessPolicy
        )
        applyPhotoKitSelection(selection)
    }

    /// Uses a selected Photos album as the active PhotoKit-backed source.
    private func selectPhotosAlbum(_ album: PhotosAlbumSummary) {
        let selection = PhotosSelection(
            mode: .album(localIdentifier: album.localIdentifier, name: album.title),
            representation: photosAssetRepresentation,
            networkAccessPolicy: photosNetworkAccessPolicy
        )

        isShowingPhotosAlbumPicker = false
        applyPhotoKitSelection(selection, knownAssetCount: album.imageAssetCount)
    }

    /// Loads PhotoKit albums for the album picker sheet.
    private func loadPhotosAlbums() {
        guard !coordinator.isLoadingPhotosAlbums else {
            return
        }

        coordinator.isLoadingPhotosAlbums = true
        coordinator.photosAlbumLoadingError = nil

        Task {
            defer {
                coordinator.isLoadingPhotosAlbums = false
            }

            do {
                let albums = try await PhotosLibraryAlbumService().fetchAlbums()
                guard !Task.isCancelled else {
                    return
                }

                coordinator.photosAlbums = albums
                coordinator.photosAlbumLoadingError = nil
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                coordinator.photosAlbums = []
                coordinator.photosAlbumLoadingError = AppErrorInfo.exportFailure(error)
            }
        }
    }

    /// Stores a PhotoKit-backed Photos Library source and starts counting image assets.
    private func applyPhotoKitSelection(
        _ selection: PhotosSelection,
        knownAssetCount: Int? = nil
    ) {
        coordinator.selectedFolderURL = nil
        coordinator.selectedPhotoAssetIdentifiers = []
        coordinator.lastSelectedPhotoAssetIdentifier = nil
        coordinator.supportedFileCountTask?.cancel()
        coordinator.supportedFileCountTask = nil
        coordinator.isCountingSupportedFiles = false
        coordinator.statistics = nil
        coordinator.packageState = .initial
        coordinator.contactSheetPreview.reset()
        coordinator.analysisProgress = nil

        coordinator.selectedAnalysisSource = .photosLibrary(selection)
        coordinator.datasetState = DatasetUIState(
            folderURL: nil,
            supportedFileCount: knownAssetCount,
            analyzedPhotoCount: nil,
            analysisStatus: .sourceSelected
        )
        coordinator.analysisPhase = knownAssetCount == 0 ? .noSupportedFiles : .ready

        if knownAssetCount == nil {
            startPhotosSelectionCount(selection)
        }
    }

    /// Starts an asynchronous image asset count for a PhotoKit-backed Photos selection.
    private func startPhotosSelectionCount(_ selection: PhotosSelection) {
        coordinator.supportedFileCountTask?.cancel()
        coordinator.isCountingSupportedFiles = true
        coordinator.analysisPhase = .scanningFiles

        let task = Task {
            do {
                let count = try await PhotosLibraryCountService().countImageAssets(in: selection)
                guard !Task.isCancelled else {
                    return
                }

                coordinator.datasetState.supportedFileCount = count
                coordinator.datasetState.analyzedPhotoCount = nil
                coordinator.datasetState.analysisStatus = .sourceSelected
                coordinator.analysisPhase = count > 0 ? .ready : .noSupportedFiles
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                coordinator.datasetState.supportedFileCount = nil
                coordinator.datasetState.analyzedPhotoCount = nil
                coordinator.datasetState.analysisStatus = .failed
                coordinator.packageState = AIPackageUIState(
                    status: .failed,
                    packageURL: nil,
                    metadataExists: false,
                    statisticsExists: false,
                    contactSheetExists: false,
                    indexExists: false,
                    archiveExists: false,
                    error: AppErrorInfo.exportFailure(error)
                )
                coordinator.analysisPhase = .failed
            }

            coordinator.isCountingSupportedFiles = false
            coordinator.supportedFileCountTask = nil
        }
        coordinator.supportedFileCountTask = task
    }

    /// Opens a folder picker and stores the AI package output folder.
    private func selectOutputFolder() {
        guard !coordinator.isAnalyzing else {
            return
        }

        guard let url = FolderSelectionPanel.selectFolder(
            canCreateDirectories: true,
            prompt: "Select Output Folder"
        ) else {
            return
        }

        do {
            try DefaultOutputFolderProvider.ensureOutputFolderExists(at: url)
            outputFolderBookmarkData = try OutputFolderBookmarkStore.bookmarkData(for: url)
        } catch {
            print("Failed to persist output folder selection: \(error)")
        }

        selectedOutputFolderURL = url
        coordinator.packageState = .initial
        coordinator.contactSheetPreview.reset()
        coordinator.analysisProgress = nil
        coordinator.analysisPhase = .ready
    }

    /// Resolves a persisted output folder, or creates the default Documents/PhotoAnalyzer folder.
    private func configureOutputFolder() {
        selectedOutputFolderURL = OutputFolderBookmarkStore.resolveBookmarkData(outputFolderBookmarkData)
            ?? DefaultOutputFolderProvider.defaultOutputFolderURL()

        do {
            try DefaultOutputFolderProvider.ensureOutputFolderExists(at: selectedOutputFolderURL)
        } catch {
            print("Failed to prepare output folder: \(error)")
        }
    }

    /// Applies current Photos analysis preferences to the active Photos source.
    private func updateSelectedPhotosPolicy() {
        guard case .photosLibrary(let selection) = coordinator.selectedAnalysisSource else {
            return
        }

        coordinator.selectedAnalysisSource = .photosLibrary(PhotosSelection(
            mode: selection.mode,
            representation: photosAssetRepresentation,
            networkAccessPolicy: photosNetworkAccessPolicy
        ))
    }

    /// Starts analysis for the selected folder.
    private func analyzeSelectedSource() {
        guard !coordinator.isAnalyzing, !coordinator.isCountingSupportedFiles else {
            return
        }

        guard let selectedAnalysisSource = coordinator.selectedAnalysisSource else {
            coordinator.analysisPhase = .noFolderSelected
            return
        }

        guard (coordinator.datasetState.supportedFileCount ?? 0) > 0 else {
            coordinator.analysisPhase = .noSupportedFiles
            return
        }

        switch selectedAnalysisSource {
        case .folder(let source):
            let task = Task {
                await analyzeSelectedFolderFiles(in: source.folderURL)
            }
            coordinator.analysisTask = task
        case .photosLibrary(let selection):
            let task = Task {
                await analyzePhotoKitSelection(selection)
            }
            coordinator.analysisTask = task
        }
    }

    /// Cancels the currently running analysis, if any.
    private func cancelAnalysis() {
        coordinator.analysisTask?.cancel()
    }

    /// Opens the persisted settings screen.
    private func openSettings() {
        refreshMetadataCacheUsage()
        isShowingSettings = true
    }

    /// Refreshes the Settings summary for the metadata cache.
    private func refreshMetadataCacheUsage() {
        metadataCacheUsage = MetadataCacheService().usage()
    }

    /// Removes all cached metadata and refreshes the Settings summary.
    private func clearMetadataCache() {
        MetadataCacheService().removeAll()
        refreshMetadataCacheUsage()
    }

    /// Runs folder analysis and package export for the selected folder.
    /// - Parameter folderURL: The folder URL selected by the user.
    private func analyzeSelectedFolderFiles(in folderURL: URL) async {
        guard !coordinator.isAnalyzing else {
            return
        }

        let outputFolderURL = selectedOutputFolderURL
        let shouldIncludeSubfolders = includeSubfolders
        let expectedSupportedFileCount = coordinator.datasetState.supportedFileCount
        let packagePaths = AIAnalysisPackagePaths(
            datasetFolderURL: folderURL,
            outputFolderURL: outputFolderURL
        )

        coordinator.beginAnalysis(packagePaths: packagePaths, progressMessage: "Starting analysis...")
        defer {
            coordinator.finishAnalysis()
        }

        do {
            let result = try await AnalysisPipelineService().run(
                request: AnalysisPipelineRequest(
                    folderURL: folderURL,
                    outputFolderURL: outputFolderURL,
                    includeSubfolders: shouldIncludeSubfolders,
                    expectedSupportedFileCount: expectedSupportedFileCount,
                    metadataCacheMaximumSizeMB: metadataCacheMaximumSizeMB,
                    exportDiagnosticReports: exportDiagnosticReports
                ),
                progressHandler: { progress in
                    Task { @MainActor in
                        coordinator.applyPipelineProgress(progress)
                    }
                }
            )

            coordinator.completeAnalysis(
                paths: result.paths,
                statistics: result.statistics,
                supportedFileCount: result.supportedFileCount,
                analyzedPhotoCount: result.analyzedPhotoCount
            )
        } catch AnalysisPipelineError.noSupportedFiles {
            coordinator.handleNoSupportedFiles(status: .folderSelected)
        } catch is CancellationError {
            coordinator.handleAnalysisCancellation(logMessage: "Folder analysis cancelled.")
        } catch {
            coordinator.handleAnalysisFailure(error, packagePaths: packagePaths, logPrefix: "AI package export failed")
        }
    }

    /// Materializes a PhotoKit-backed Photos Library selection and runs the file-based pipeline.
    private func analyzePhotoKitSelection(_ selection: PhotosSelection) async {
        guard !coordinator.isAnalyzing else {
            return
        }

        let outputFolderURL = selectedOutputFolderURL
        let datasetName = selection.displayName
        let packagePaths = AIAnalysisPackagePaths(
            datasetName: datasetName,
            datasetFolderURL: FileManager.default.temporaryDirectory,
            outputFolderURL: outputFolderURL
        )

        coordinator.beginAnalysis(packagePaths: packagePaths, progressMessage: "Preparing Photos assets...")
        defer {
            coordinator.finishAnalysis()
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
                        coordinator.applyPipelineProgress(progress)
                    }
                }
            )

            coordinator.completeAnalysis(
                paths: result.paths,
                statistics: result.statistics,
                supportedFileCount: result.supportedFileCount,
                analyzedPhotoCount: result.analyzedPhotoCount,
                error: AppErrorInfo.photosSkippedAssets(result.skippedAssets)
            )
        } catch AnalysisPipelineError.noSupportedFiles {
            coordinator.handleNoSupportedFiles(status: .sourceSelected)
        } catch is CancellationError {
            coordinator.handleAnalysisCancellation(logMessage: "Photos analysis cancelled.")
        } catch {
            coordinator.handleAnalysisFailure(error, packagePaths: packagePaths, logPrefix: "Photos package export failed")
        }
    }

    /// Starts an asynchronous supported file count for the selected folder.
    /// - Parameters:
    ///   - folderURL: The selected folder URL.
    ///   - includeSubfolders: Whether subfolders should be scanned recursively.
    private func startSupportedFileCount(for folderURL: URL, includeSubfolders: Bool) {
        coordinator.supportedFileCountTask?.cancel()
        coordinator.isCountingSupportedFiles = true
        coordinator.analysisPhase = .scanningFiles

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

            coordinator.datasetState.supportedFileCount = fileCount
            coordinator.datasetState.analyzedPhotoCount = nil
            coordinator.datasetState.analysisStatus = .folderSelected
            coordinator.analysisPhase = fileCount > 0 ? .ready : .noSupportedFiles
            coordinator.isCountingSupportedFiles = false
            coordinator.supportedFileCountTask = nil
        }
        coordinator.supportedFileCountTask = task
    }

    /// Recounts supported files after scan options change.
    private func updateSupportedFileCountForSelectedFolder() {
        guard !coordinator.isAnalyzing,
              !coordinator.isCountingSupportedFiles,
              let selectedFolderURL = coordinator.selectedFolderURL else {
            return
        }

        coordinator.selectedAnalysisSource = .folder(FolderAnalysisSource(
            folderURL: selectedFolderURL,
            includeSubfolders: includeSubfolders
        ))

        coordinator.statistics = nil
        coordinator.packageState = .initial
        coordinator.contactSheetPreview.reset()
        coordinator.analysisProgress = nil
        coordinator.datasetState.supportedFileCount = nil
        coordinator.datasetState.analyzedPhotoCount = nil
        coordinator.datasetState.analysisStatus = .folderSelected
        startSupportedFileCount(
            for: selectedFolderURL,
            includeSubfolders: includeSubfolders
        )
    }

    /// Opens the generated contact sheet in a dedicated viewer.
    private func openContactSheetViewer() {
        guard coordinator.contactSheetPreview.canOpenViewer else {
            return
        }

        contactSheetViewerPresenter.open(
            pageURLs: coordinator.contactSheetPreview.pageURLs,
            initialPageIndex: coordinator.contactSheetPreview.currentPageIndex
        )
    }

    /// Opens the generated package folder.
    private func openPackage() {
        guard let packageURL = coordinator.packageState.packageURL else {
            return
        }

        PackageWorkspaceActions.openPackage(at: packageURL)
    }

    /// Reveals the generated package archive in Finder.
    private func revealArchive() {
        guard let packageURL = coordinator.packageState.packageURL else {
            return
        }

        PackageWorkspaceActions.revealArchive(forPackageAt: packageURL)
    }
}

/// Preview provider for the PhotoAnalyzer content view.
#Preview {
    ContentView()
}
