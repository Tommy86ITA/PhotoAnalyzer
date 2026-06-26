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

    /// The security-scoped folder URL selected by the user.
    @State private var selectedFolderURL: URL?

    /// The currently selected analysis source.
    @State private var selectedAnalysisSource: AnalysisSource?

    /// Selected PhotoKit asset identifiers used to build a manual Photos Library source.
    @State private var selectedPhotoAssetIdentifiers = Set<String>()

    /// Last manually selected PhotoKit asset, used as the anchor for shift-selection.
    @State private var lastSelectedPhotoAssetIdentifier: String?

    /// Security-scoped output folder for generated AI packages.
    @State private var selectedOutputFolderURL = DefaultOutputFolderProvider.defaultOutputFolderURL()

    /// Whether selected dataset subfolders should be scanned.
    @AppStorage("analysis.includeSubfolders") private var includeSubfolders = false

    /// Whether Photos Library analysis should use unmodified original assets.
    @AppStorage("photos.useUnmodifiedOriginals") private var useUnmodifiedPhotosOriginals = true

    /// Whether Photos Library analysis may download missing iCloud originals.
    @AppStorage("photos.downloadMissingOriginals") private var downloadMissingPhotosOriginals = false

    /// Security-scoped bookmark for the user-selected output folder.
    @AppStorage("outputFolder.bookmark") private var outputFolderBookmarkData = Data()

    /// User-facing state for the selected dataset.
    @State private var datasetState = DatasetUIState.initial

    /// User-facing state for the latest AI package export.
    @State private var packageState = AIPackageUIState.initial

    /// The latest statistics computed from the analyzed photos.
    @State private var statistics: PhotoStatistics?

    /// Contact sheet page browsing state for the latest package export.
    @State private var contactSheetPreview = ContactSheetPreviewState()

    /// Presenter that owns the dedicated contact sheet viewer window.
    @State private var contactSheetViewerPresenter = ContactSheetViewerPresenter()

    /// Whether a folder analysis is currently running.
    @State private var isAnalyzing = false

    /// Whether the selected folder is currently being scanned for supported files.
    @State private var isCountingSupportedFiles = false

    /// The currently running analysis task, if any.
    @State private var analysisTask: Task<Void, Never>?

    /// The currently running supported file count task, if any.
    @State private var supportedFileCountTask: Task<Void, Never>?

    /// The current operation phase shown at the bottom of the interface.
    @State private var analysisPhase: AnalysisPhase = .ready

    /// The current progress for the complete analysis pipeline.
    @State private var analysisProgress: AnalysisProgress?

    /// Whether the dedicated settings sheet is visible.
    @State private var isShowingSettings = false

    /// Whether the PhotoKit album picker sheet is visible.
    @State private var isShowingPhotosAlbumPicker = false

    /// Whether the PhotoKit asset picker sheet is visible.
    @State private var isShowingPhotosAssetPicker = false

    /// Image assets available for manual PhotoKit-backed Photos selection.
    @State private var photosAssets: [PhotosAssetSummary] = []

    /// Whether Photos assets are currently loading.
    @State private var isLoadingPhotosAssets = false

    /// Asset loading error shown in the asset picker sheet.
    @State private var photosAssetLoadingError: AppErrorInfo?

    /// Albums available for PhotoKit-backed Photos selection.
    @State private var photosAlbums: [PhotosAlbumSummary] = []

    /// Whether Photos albums are currently loading.
    @State private var isLoadingPhotosAlbums = false

    /// Album loading error shown in the album picker sheet.
    @State private var photosAlbumLoadingError: AppErrorInfo?

    /// The view hierarchy for the PhotoAnalyzer interface.
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Layout.contentSpacing) {
                AppHeaderView()

                DatasetActionView(
                    datasetState: datasetState,
                    sourceIconName: sourceIconName,
                    sourceText: sourceText,
                    sourcePath: sourcePath,
                    isSourcePlaceholder: selectedAnalysisSource == nil,
                    isFolderSource: isFolderSource,
                    canAnalyze: canAnalyzeSelectedSource,
                    isAnalyzing: isAnalyzing,
                    isCountingSupportedFiles: isCountingSupportedFiles,
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
                    statusMessage: analysisPhase.displayText,
                    isBusy: isAnalyzing || isCountingSupportedFiles,
                    progress: footerProgress
                )

                GeometryReader { proxy in
                    HStack(alignment: .top, spacing: Layout.dashboardSpacing) {
                        VStack(spacing: Layout.mainColumnSpacing) {
                            AIPackageCardView(
                                packageState: packageState,
                                isAnalyzing: isAnalyzing,
                                openPackage: openPackage,
                                revealArchive: revealArchive
                            )

                            DatasetOverviewView(statistics: statistics)
                        }
                        .frame(maxWidth: .infinity, maxHeight: proxy.size.height, alignment: .top)

                        ContactSheetPreviewView(
                            image: contactSheetPreview.image,
                            packageStatus: packageState.status,
                            currentPageIndex: contactSheetPreview.currentPageIndex,
                            pageCount: contactSheetPreview.pageCount,
                            previousPage: { contactSheetPreview.showPreviousPage() },
                            nextPage: { contactSheetPreview.showNextPage() },
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
            .frame(width: 0, height: 0)
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
                outputFolderURL: selectedOutputFolderURL,
                canEditSettings: !isAnalyzing && !isCountingSupportedFiles,
                selectOutputFolder: selectOutputFolder,
                dismiss: { isShowingSettings = false }
            )
        }
        .sheet(isPresented: $isShowingPhotosAlbumPicker) {
            PhotosAlbumPickerView(
                albums: photosAlbums,
                isLoading: isLoadingPhotosAlbums,
                error: photosAlbumLoadingError,
                selectAlbum: selectPhotosAlbum,
                refresh: loadPhotosAlbums,
                dismiss: { isShowingPhotosAlbumPicker = false }
            )
        }
        .sheet(isPresented: $isShowingPhotosAssetPicker) {
            PhotosAssetPickerView(
                assets: photosAssets,
                isLoading: isLoadingPhotosAssets,
                error: photosAssetLoadingError,
                selectedAssetIdentifiers: selectedPhotoAssetIdentifiers,
                toggleAsset: toggleSelectedPhotoAsset,
                selectAllAssets: selectAllPhotoAssets,
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
            preflightPhotosLibraryAuthorization()
        }
    }

    private var sourceIconName: String {
        switch selectedAnalysisSource {
        case .folder:
            "folder.fill"
        case .photosLibrary:
            "photo.on.rectangle.angled"
        case nil:
            "folder"
        }
    }

    private var sourceText: String {
        selectedAnalysisSource?.displayName ?? "No source selected"
    }

    private var sourcePath: String? {
        guard case .folder(let source) = selectedAnalysisSource else {
            return nil
        }
        return source.folderURL.path
    }

    private var canAnalyzeSelectedSource: Bool {
        guard selectedAnalysisSource != nil else {
            return false
        }
        return (datasetState.supportedFileCount ?? 0) > 0
    }

    private var isFolderSource: Bool {
        if case .folder = selectedAnalysisSource {
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
        if let analysisProgress {
            return analysisProgress
        }

        guard isAnalyzing || isCountingSupportedFiles else {
            return nil
        }

        return AnalysisProgress(fractionCompleted: 0, message: analysisPhase.displayText)
    }

    /// Opens a folder picker and stores the selected folder path.
    private func selectFolder() {
        guard !isAnalyzing, !isCountingSupportedFiles else {
            return
        }

        guard let url = FolderSelectionPanel.selectFolder() else {
            return
        }

        selectedFolderURL = url
        selectedAnalysisSource = .folder(FolderAnalysisSource(
            folderURL: url,
            includeSubfolders: includeSubfolders
        ))
        selectedPhotoAssetIdentifiers = []
        lastSelectedPhotoAssetIdentifier = nil
        statistics = nil
        packageState = .initial
        contactSheetPreview.reset()
        analysisProgress = nil

        datasetState = DatasetUIState(
            folderURL: url,
            supportedFileCount: nil,
            analyzedPhotoCount: nil,
            analysisStatus: .folderSelected
        )
        startSupportedFileCount(for: url, includeSubfolders: includeSubfolders)
    }

    /// Opens the PhotoKit asset picker.
    private func choosePhotosAssets() {
        guard !isAnalyzing, !isCountingSupportedFiles else {
            return
        }

        isShowingPhotosAssetPicker = true
        loadPhotosAssets()
    }

    /// Loads PhotoKit assets for the manual Photos picker sheet.
    private func loadPhotosAssets() {
        guard !isLoadingPhotosAssets else {
            return
        }

        isLoadingPhotosAssets = true
        photosAssetLoadingError = nil

        Task {
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

            isLoadingPhotosAssets = false
        }
    }

    /// Toggles a PhotoKit asset in the manual Photos selection sheet.
    private func toggleSelectedPhotoAsset(_ asset: PhotosAssetSummary) {
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

    /// Selects a contiguous range from the last selected asset to the current asset.
    private func selectPhotoAssetRange(
        through asset: PhotosAssetSummary,
        extendsExistingSelection: Bool
    ) {
        guard let anchorIdentifier = lastSelectedPhotoAssetIdentifier,
              let anchorIndex = photosAssets.firstIndex(where: { $0.localIdentifier == anchorIdentifier }),
              let currentIndex = photosAssets.firstIndex(of: asset) else {
            selectedPhotoAssetIdentifiers = [asset.localIdentifier]
            lastSelectedPhotoAssetIdentifier = asset.localIdentifier
            return
        }

        let bounds = min(anchorIndex, currentIndex)...max(anchorIndex, currentIndex)
        let rangeIdentifiers = Set(photosAssets[bounds].map(\.localIdentifier))

        if extendsExistingSelection {
            selectedPhotoAssetIdentifiers.formUnion(rangeIdentifiers)
        } else {
            selectedPhotoAssetIdentifiers = rangeIdentifiers
        }
    }

    /// Selects every loaded PhotoKit asset in the manual Photos selection sheet.
    private func selectAllPhotoAssets() {
        selectedPhotoAssetIdentifiers = Set(photosAssets.map(\.localIdentifier))
        lastSelectedPhotoAssetIdentifier = photosAssets.last?.localIdentifier
    }

    /// Clears the manual PhotoKit asset selection.
    private func clearSelectedPhotoAssets() {
        selectedPhotoAssetIdentifiers = []
        lastSelectedPhotoAssetIdentifier = nil
    }

    /// Stores manually selected PhotoKit assets as the active Photos source.
    private func confirmSelectedPhotosAssets() {
        guard !selectedPhotoAssetIdentifiers.isEmpty else {
            return
        }

        let identifiers = photosAssets
            .map(\.localIdentifier)
            .filter { selectedPhotoAssetIdentifiers.contains($0) }

        selectedAnalysisSource = .photosLibrary(PhotosSelection(
            mode: .assets(localIdentifiers: identifiers),
            representation: photosAssetRepresentation,
            networkAccessPolicy: photosNetworkAccessPolicy
        ))
        selectedFolderURL = nil
        supportedFileCountTask?.cancel()
        supportedFileCountTask = nil
        isCountingSupportedFiles = false
        statistics = nil
        packageState = .initial
        contactSheetPreview.reset()
        analysisProgress = nil
        datasetState = DatasetUIState(
            folderURL: nil,
            supportedFileCount: identifiers.count,
            analyzedPhotoCount: nil,
            analysisStatus: .sourceSelected
        )
        analysisPhase = .ready
        isShowingPhotosAssetPicker = false
    }

    /// Opens the PhotoKit album picker.
    private func choosePhotosAlbum() {
        guard !isAnalyzing, !isCountingSupportedFiles else {
            return
        }

        isShowingPhotosAlbumPicker = true
        loadPhotosAlbums()
    }

    /// Uses the complete Photos Library as the active PhotoKit-backed source.
    private func useEntirePhotosLibrary() {
        guard !isAnalyzing, !isCountingSupportedFiles else {
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
        guard !isLoadingPhotosAlbums else {
            return
        }

        isLoadingPhotosAlbums = true
        photosAlbumLoadingError = nil

        Task {
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

            isLoadingPhotosAlbums = false
        }
    }

    /// Stores a PhotoKit-backed Photos Library source and starts counting image assets.
    private func applyPhotoKitSelection(
        _ selection: PhotosSelection,
        knownAssetCount: Int? = nil
    ) {
        selectedFolderURL = nil
        selectedPhotoAssetIdentifiers = []
        lastSelectedPhotoAssetIdentifier = nil
        supportedFileCountTask?.cancel()
        supportedFileCountTask = nil
        isCountingSupportedFiles = false
        statistics = nil
        packageState = .initial
        contactSheetPreview.reset()
        analysisProgress = nil

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

    /// Opens a folder picker and stores the AI package output folder.
    private func selectOutputFolder() {
        guard !isAnalyzing else {
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
        packageState = .initial
        contactSheetPreview.reset()
        analysisProgress = nil
        analysisPhase = .ready
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

    /// Triggers the Photos permission prompt once near app startup when access has not been decided yet.
    private func preflightPhotosLibraryAuthorization() {
        Task {
            do {
                try await PhotosLibraryAuthorizationService().requestReadAccessIfNeeded()
            } catch PhotosLibraryAssetExporterError.unauthorized {
                // The user can still grant access later from System Settings.
            } catch {
                print("Photos Library authorization preflight failed: \(error)")
            }
        }
    }

    /// Applies current Photos analysis preferences to the active Photos source.
    private func updateSelectedPhotosPolicy() {
        guard case .photosLibrary(let selection) = selectedAnalysisSource else {
            return
        }

        selectedAnalysisSource = .photosLibrary(PhotosSelection(
            mode: selection.mode,
            representation: photosAssetRepresentation,
            networkAccessPolicy: photosNetworkAccessPolicy
        ))
    }

    /// Starts analysis for the selected folder.
    private func analyzeSelectedSource() {
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
                await analyzeSelectedFolderFiles(in: source.folderURL)
            }
            analysisTask = task
        case .photosLibrary(let selection):
            let task = Task {
                await analyzePhotoKitSelection(selection)
            }
            analysisTask = task
        }
    }

    /// Starts analysis for the selected folder.
    private func analyzeSelectedFolder() {
        guard let selectedFolderURL else {
            analysisPhase = .noFolderSelected
            return
        }

        let task = Task {
            await analyzeSelectedFolderFiles(in: selectedFolderURL)
        }
        analysisTask = task
    }

    /// Cancels the currently running analysis, if any.
    private func cancelAnalysis() {
        analysisTask?.cancel()
    }

    /// Opens the persisted settings screen.
    private func openSettings() {
        isShowingSettings = true
    }

    /// Runs folder analysis and package export for the selected folder.
    /// - Parameter folderURL: The folder URL selected by the user.
    private func analyzeSelectedFolderFiles(in folderURL: URL) async {
        guard !isAnalyzing else {
            return
        }

        let outputFolderURL = selectedOutputFolderURL
        let shouldIncludeSubfolders = includeSubfolders
        let expectedSupportedFileCount = datasetState.supportedFileCount
        let packagePaths = AIAnalysisPackagePaths(
            datasetFolderURL: folderURL,
            outputFolderURL: outputFolderURL
        )

        isAnalyzing = true
        supportedFileCountTask?.cancel()
        supportedFileCountTask = nil
        isCountingSupportedFiles = false
        defer {
            isAnalyzing = false
            analysisTask = nil
        }

        statistics = nil
        contactSheetPreview.reset()
        analysisProgress = AnalysisProgress(fractionCompleted: 0, message: "Starting analysis...")
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

        do {
            let result = try await AnalysisPipelineService().run(
                request: AnalysisPipelineRequest(
                    folderURL: folderURL,
                    outputFolderURL: outputFolderURL,
                    includeSubfolders: shouldIncludeSubfolders,
                    expectedSupportedFileCount: expectedSupportedFileCount
                ),
                progressHandler: { progress in
                    Task { @MainActor in
                        applyPipelineProgress(progress)
                    }
                }
            )

            statistics = result.statistics
            datasetState.supportedFileCount = result.supportedFileCount
            datasetState.analyzedPhotoCount = result.analyzedPhotoCount
            datasetState.analysisStatus = .completed
            packageState = AIPackageUIState(packageURL: result.paths.packageURL)
            analysisPhase = .completed
            contactSheetPreview.load(from: result.paths.packageURL)
        } catch AnalysisPipelineError.noSupportedFiles {
            datasetState.supportedFileCount = 0
            datasetState.analysisStatus = .folderSelected
            packageState = .initial
            analysisPhase = .noSupportedFiles
            analysisProgress = nil
        } catch is CancellationError {
            print("Folder analysis cancelled.")
            statistics = nil
            contactSheetPreview.reset()
            datasetState.analysisStatus = .cancelled
            datasetState.analyzedPhotoCount = nil
            packageState = .initial
            analysisPhase = .cancelled
            analysisProgress = nil
        } catch {
            let appError = AppErrorInfo.exportFailure(error)
            print("AI package export failed: \(appError.debugDescription)")
            datasetState.analysisStatus = statistics == nil ? .failed : .completedWithExportError
            packageState = AIPackageUIState(packageURL: packagePaths.packageURL, error: appError)
            analysisPhase = statistics == nil ? .failed : .exportFailed
            analysisProgress = nil
        }
    }

    /// Materializes a PhotoKit-backed Photos Library selection and runs the file-based pipeline.
    private func analyzePhotoKitSelection(_ selection: PhotosSelection) async {
        guard !isAnalyzing else {
            return
        }

        let outputFolderURL = selectedOutputFolderURL
        let datasetName = selection.displayName
        let packagePaths = AIAnalysisPackagePaths(
            datasetName: datasetName,
            datasetFolderURL: FileManager.default.temporaryDirectory,
            outputFolderURL: outputFolderURL
        )

        isAnalyzing = true
        supportedFileCountTask?.cancel()
        supportedFileCountTask = nil
        isCountingSupportedFiles = false
        defer {
            isAnalyzing = false
            analysisTask = nil
        }

        statistics = nil
        contactSheetPreview.reset()
        analysisProgress = AnalysisProgress(fractionCompleted: 0, message: "Preparing Photos assets...")
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

        do {
            let result = try await PhotosAnalysisPipelineService().run(
                request: PhotosAnalysisPipelineRequest(
                    selection: selection,
                    outputFolderURL: outputFolderURL,
                    datasetName: datasetName
                ),
                progressHandler: { progress in
                    Task { @MainActor in
                        applyPipelineProgress(progress)
                    }
                }
            )

            statistics = result.statistics
            datasetState.supportedFileCount = result.supportedFileCount
            datasetState.analyzedPhotoCount = result.analyzedPhotoCount
            datasetState.analysisStatus = .completed
            packageState = AIPackageUIState(
                packageURL: result.paths.packageURL,
                error: AppErrorInfo.photosSkippedAssets(result.skippedAssets)
            )
            analysisPhase = .completed
            contactSheetPreview.load(from: result.paths.packageURL)
        } catch AnalysisPipelineError.noSupportedFiles {
            datasetState.supportedFileCount = 0
            datasetState.analysisStatus = .sourceSelected
            packageState = .initial
            analysisPhase = .noSupportedFiles
            analysisProgress = nil
        } catch is CancellationError {
            print("Photos analysis cancelled.")
            statistics = nil
            contactSheetPreview.reset()
            datasetState.analysisStatus = .cancelled
            datasetState.analyzedPhotoCount = nil
            packageState = .initial
            analysisPhase = .cancelled
            analysisProgress = nil
        } catch {
            let appError = AppErrorInfo.exportFailure(error)
            print("Photos package export failed: \(appError.debugDescription)")
            datasetState.analysisStatus = statistics == nil ? .failed : .completedWithExportError
            packageState = AIPackageUIState(packageURL: packagePaths.packageURL, error: appError)
            analysisPhase = statistics == nil ? .failed : .exportFailed
            analysisProgress = nil
        }
    }

    /// Applies service progress to the dashboard state.
    private func applyPipelineProgress(_ progress: AnalysisProgress) {
        analysisProgress = progress
        if let phase = progress.phase {
            analysisPhase = phase
        }
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

    /// Recounts supported files after scan options change.
    private func updateSupportedFileCountForSelectedFolder() {
        guard !isAnalyzing, !isCountingSupportedFiles, let selectedFolderURL else {
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

    /// Opens the generated contact sheet in a dedicated viewer.
    private func openContactSheetViewer() {
        guard contactSheetPreview.canOpenViewer else {
            return
        }

        contactSheetViewerPresenter.open(
            pageURLs: contactSheetPreview.pageURLs,
            initialPageIndex: contactSheetPreview.currentPageIndex
        )
    }

    /// Opens the generated package folder.
    private func openPackage() {
        guard let packageURL = packageState.packageURL else {
            return
        }

        PackageWorkspaceActions.openPackage(at: packageURL)
    }

    /// Reveals the generated package archive in Finder.
    private func revealArchive() {
        guard let packageURL = packageState.packageURL else {
            return
        }

        PackageWorkspaceActions.revealArchive(forPackageAt: packageURL)
    }
}

/// Preview provider for the PhotoAnalyzer content view.
#Preview {
    ContentView()
}
