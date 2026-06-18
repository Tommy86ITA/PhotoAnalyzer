//
//  ContentView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 15/06/2026.
//

import AppKit
import SwiftUI

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
        static let contactSheetViewerWidth: CGFloat = 1000
        static let contactSheetViewerHeight: CGFloat = 720
        static let contactSheetViewerMinimumWidth: CGFloat = 760
        static let contactSheetViewerMinimumHeight: CGFloat = 520
    }

    /// The security-scoped folder URL selected by the user.
    @State private var selectedFolderURL: URL?

    /// Optional security-scoped output folder for generated AI packages.
    @State private var selectedOutputFolderURL: URL?

    /// Whether selected dataset subfolders should be scanned.
    @State private var includeSubfolders = false

    /// User-facing state for the selected dataset.
    @State private var datasetState = DatasetUIState.initial

    /// User-facing state for the latest AI package export.
    @State private var packageState = AIPackageUIState.initial

    /// The latest statistics computed from the analyzed photos.
    @State private var statistics: PhotoStatistics?

    /// Contact sheet page browsing state for the latest package export.
    @State private var contactSheetPreview = ContactSheetPreviewState()

    /// Dedicated macOS window for inspecting the generated contact sheet.
    @State private var contactSheetViewerWindow: NSWindow?

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

    /// The view hierarchy for the PhotoAnalyzer interface.
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Layout.contentSpacing) {
                AppHeaderView()

                DatasetActionView(
                    datasetState: datasetState,
                    outputFolderURL: selectedOutputFolderURL,
                    isAnalyzing: isAnalyzing,
                    isCountingSupportedFiles: isCountingSupportedFiles,
                    includeSubfolders: $includeSubfolders,
                    selectFolder: selectFolder,
                    selectOutputFolder: selectOutputFolder,
                    analyze: analyzeSelectedFolder,
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

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        selectedFolderURL = url
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

    /// Opens a folder picker and stores the optional AI package output folder.
    private func selectOutputFolder() {
        guard !isAnalyzing else {
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Output Folder"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        selectedOutputFolderURL = url
        packageState = .initial
        contactSheetPreview.reset()
        analysisProgress = nil
        analysisPhase = .ready
    }

    /// Starts analysis for the selected folder.
    private func analyzeSelectedFolder() {
        guard !isAnalyzing, !isCountingSupportedFiles else {
            return
        }

        guard let selectedFolderURL else {
            analysisPhase = .noFolderSelected
            return
        }

        guard (datasetState.supportedFileCount ?? 0) > 0 else {
            analysisPhase = .noSupportedFiles
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
            errorMessage: nil
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
            loadContactSheetPreview(from: result.paths.packageURL)
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
            let errorDescription = "\(error.localizedDescription) (\(String(reflecting: error)))"
            print("AI package export failed: \(errorDescription)")
            datasetState.analysisStatus = statistics == nil ? .failed : .completedWithExportError
            packageState = AIPackageUIState(packageURL: packagePaths.packageURL, errorMessage: errorDescription)
            analysisPhase = statistics == nil ? .failed : .exportFailed
            analysisProgress = nil
        }
    }

    /// Applies service progress to the dashboard state.
    private func applyPipelineProgress(_ progress: AnalysisProgress) {
        analysisProgress = progress
        analysisPhase = phase(forProgressMessage: progress.message)
    }

    /// Maps service progress messages to the broader UI phase.
    private func phase(forProgressMessage message: String) -> AnalysisPhase {
        if message.hasPrefix("Scanning files") {
            return .scanningFiles
        } else if message.hasPrefix("Reading metadata") {
            return .readingMetadata
        } else if message.hasPrefix("Generating statistics") {
            return .generatingStatistics
        } else if message.hasPrefix("Exporting") {
            return .exportingAIPackage
        } else if message.hasPrefix("Writing contact sheet") || message.hasPrefix("Generating contact sheet") {
            return .generatingContactSheet
        } else if message.hasPrefix("Archiving") {
            return .archivingPackage
        } else if message == "Package generated" {
            return .completed
        }

        return analysisPhase
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
                supportedFileCount(in: folderURL, includeSubfolders: includeSubfolders)
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

    /// Counts supported image files in the selected folder.
    /// - Parameters:
    ///   - folderURL: The selected folder URL.
    ///   - includeSubfolders: Whether subfolders should be scanned recursively.
    /// - Returns: Number of supported image files found inside the folder.
    private nonisolated func supportedFileCount(in folderURL: URL, includeSubfolders: Bool) -> Int {
        let accessGranted = folderURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        return ImageFileScanner().imageFileURLs(in: folderURL, includeSubfolders: includeSubfolders).count
    }

    /// Recounts supported files after scan options change.
    private func updateSupportedFileCountForSelectedFolder() {
        guard !isAnalyzing, !isCountingSupportedFiles, let selectedFolderURL else {
            return
        }

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

    /// Loads the generated contact sheet preview image.
    /// - Parameter packageURL: The package folder URL.
    private func loadContactSheetPreview(from packageURL: URL) {
        contactSheetPreview.load(from: packageURL)
    }

    /// Opens the generated contact sheet in a dedicated viewer.
    private func openContactSheetViewer() {
        guard contactSheetPreview.canOpenViewer else {
            return
        }

        if let contactSheetViewerWindow, contactSheetViewerWindow.isVisible {
            contactSheetViewerWindow.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Layout.contactSheetViewerWidth,
                height: Layout.contactSheetViewerHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Contact Sheet"
        window.minSize = NSSize(
            width: Layout.contactSheetViewerMinimumWidth,
            height: Layout.contactSheetViewerMinimumHeight
        )
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: ContactSheetViewerView(
                pageURLs: contactSheetPreview.pageURLs,
                initialPageIndex: contactSheetPreview.currentPageIndex
            ) { [weak window] in
                window?.close()
            }
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        contactSheetViewerWindow = window
    }

    /// Opens the generated package folder.
    private func openPackage() {
        guard let packageURL = packageState.packageURL else {
            return
        }

        NSWorkspace.shared.open(packageURL)
    }

    /// Reveals the generated package archive in Finder.
    private func revealArchive() {
        guard let packageURL = packageState.packageURL else {
            return
        }

        let archiveURL = AIAnalysisPackagePaths(packageURL: packageURL).archiveURL
        NSWorkspace.shared.activateFileViewerSelecting([archiveURL])
    }
}

/// Preview provider for the PhotoAnalyzer content view.
#Preview {
    ContentView()
}
