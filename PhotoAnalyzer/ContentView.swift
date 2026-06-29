//
//  ContentView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 15/06/2026.
//

import OSLog
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
            coordinator.updateSupportedFileCountForSelectedFolder(includeSubfolders: includeSubfolders)
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
                albums: coordinator.photosSelection.albums,
                isLoading: coordinator.photosSelection.isLoadingAlbums,
                error: coordinator.photosSelection.albumLoadingError,
                selectAlbum: selectPhotosAlbum,
                refresh: coordinator.loadPhotosAlbums,
                dismiss: { isShowingPhotosAlbumPicker = false }
            )
        }
        .sheet(isPresented: $isShowingPhotosAssetPicker) {
            PhotosAssetPickerView(
                assets: coordinator.photosSelection.assets,
                isLoading: coordinator.photosSelection.isLoadingAssets,
                error: coordinator.photosSelection.assetLoadingError,
                selectedAssetIdentifiers: coordinator.photosSelection.selectedAssetIdentifiers,
                toggleAsset: toggleSelectedPhotoAsset,
                selectAssets: selectPhotoAssets,
                clearSelection: clearSelectedPhotoAssets,
                confirmSelection: confirmSelectedPhotosAssets,
                refresh: coordinator.loadPhotosAssets,
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

        coordinator.selectFolder(url, includeSubfolders: includeSubfolders)
    }

    /// Opens the PhotoKit asset picker.
    private func choosePhotosAssets() {
        guard !coordinator.isAnalyzing, !coordinator.isCountingSupportedFiles else {
            return
        }

        isShowingPhotosAssetPicker = true
        coordinator.loadPhotosAssets()
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

        coordinator.toggleSelectedPhotoAsset(
            asset,
            in: orderedAssets,
            isCommandSelection: isCommandSelection,
            isRangeSelection: isRangeSelection
        )
    }

    /// Selects the provided PhotoKit assets in the manual Photos selection sheet.
    private func selectPhotoAssets(_ assets: [PhotosAssetSummary]) {
        coordinator.selectPhotoAssets(assets)
    }

    /// Clears the manual PhotoKit asset selection.
    private func clearSelectedPhotoAssets() {
        coordinator.clearSelectedPhotoAssets()
    }

    /// Stores manually selected PhotoKit assets as the active Photos source.
    private func confirmSelectedPhotosAssets() {
        if coordinator.confirmSelectedPhotosAssets(
            representation: photosAssetRepresentation,
            networkAccessPolicy: photosNetworkAccessPolicy
        ) {
            isShowingPhotosAssetPicker = false
        }
    }

    /// Opens the PhotoKit album picker.
    private func choosePhotosAlbum() {
        guard !coordinator.isAnalyzing, !coordinator.isCountingSupportedFiles else {
            return
        }

        isShowingPhotosAlbumPicker = true
        coordinator.loadPhotosAlbums()
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
        coordinator.applyPhotoKitSelection(selection)
    }

    /// Uses a selected Photos album as the active PhotoKit-backed source.
    private func selectPhotosAlbum(_ album: PhotosAlbumSummary) {
        let selection = PhotosSelection(
            mode: .album(localIdentifier: album.localIdentifier, name: album.title),
            representation: photosAssetRepresentation,
            networkAccessPolicy: photosNetworkAccessPolicy
        )

        isShowingPhotosAlbumPicker = false
        coordinator.applyPhotoKitSelection(selection, knownAssetCount: album.imageAssetCount)
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
            AppLogger.security.error("Failed to persist output folder selection: \(error.localizedDescription, privacy: .public)")
        }

        selectedOutputFolderURL = url
        coordinator.resetGeneratedPackageState()
        coordinator.analysisPhase = AnalysisPhase.ready
    }

    /// Resolves a persisted output folder, or creates the default Documents/PhotoAnalyzer folder.
    private func configureOutputFolder() {
        selectedOutputFolderURL = OutputFolderBookmarkStore.resolveBookmarkData(outputFolderBookmarkData)
            ?? DefaultOutputFolderProvider.defaultOutputFolderURL()

        do {
            try DefaultOutputFolderProvider.ensureOutputFolderExists(at: selectedOutputFolderURL)
        } catch {
            AppLogger.security.error("Failed to prepare output folder: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Applies current Photos analysis preferences to the active Photos source.
    private func updateSelectedPhotosPolicy() {
        coordinator.updateSelectedPhotosPolicy(
            representation: photosAssetRepresentation,
            networkAccessPolicy: photosNetworkAccessPolicy
        )
    }

    /// Starts analysis for the selected folder.
    private func analyzeSelectedSource() {
        coordinator.analyzeSelectedSource(
            outputFolderURL: selectedOutputFolderURL,
            includeSubfolders: includeSubfolders,
            metadataCacheMaximumSizeMB: metadataCacheMaximumSizeMB,
            exportDiagnosticReports: exportDiagnosticReports
        )
    }

    /// Cancels the currently running analysis, if any.
    private func cancelAnalysis() {
        coordinator.cancelAnalysis()
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
