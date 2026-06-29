//
//  AnalysisWorkspaceView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 29/06/2026.
//

import SwiftUI

/// Primary dashboard layout for the selected analysis source and generated package.
struct AnalysisWorkspaceView: View {
    private enum Layout {
        static let contentSpacing: CGFloat = 16
        static let contentPadding: CGFloat = 26
        static let mainColumnSpacing: CGFloat = 12
        static let dashboardSpacing: CGFloat = 18
    }

    let coordinator: AnalysisCoordinator
    let useUnmodifiedPhotosOriginals: Bool
    let downloadMissingPhotosOriginals: Bool
    let includeSubfolders: Binding<Bool>
    let selectFolder: () -> Void
    let choosePhotosAssets: () -> Void
    let choosePhotosAlbum: () -> Void
    let useEntirePhotosLibrary: () -> Void
    let openSettings: () -> Void
    let analyzeSelectedSource: () -> Void
    let cancelAnalysis: () -> Void
    let openPackage: () -> Void
    let revealArchive: () -> Void
    let openContactSheetViewer: () -> Void

    var body: some View {
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
                includeSubfolders: includeSubfolders,
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

    private var footerProgress: AnalysisProgress? {
        if let analysisProgress = coordinator.analysisProgress {
            return analysisProgress
        }

        guard coordinator.isAnalyzing || coordinator.isCountingSupportedFiles else {
            return nil
        }

        return AnalysisProgress(fractionCompleted: 0, message: coordinator.analysisPhase.displayText)
    }
}
