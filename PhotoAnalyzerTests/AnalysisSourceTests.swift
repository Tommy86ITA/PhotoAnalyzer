//
//  AnalysisSourceTests.swift
//  PhotoAnalyzerTests
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Foundation
import Testing
@testable import PhotoAnalyzer

struct AnalysisSourceTests {
    @Test func folderSourceUsesFolderNameForDisplay() {
        let source = AnalysisSource.folder(FolderAnalysisSource(
            folderURL: URL(fileURLWithPath: "/Users/example/Pictures/Trip", isDirectory: true),
            includeSubfolders: true
        ))

        #expect(source.displayName == "Trip")
    }

    @Test func photosSelectionDefaultsToOriginalLocalOnlyAssets() {
        let selection = PhotosSelection(mode: .assets(localIdentifiers: ["asset-1", "asset-2"]))

        #expect(selection.representation == .original)
        #expect(selection.allowsNetworkAccess == false)
        #expect(selection.displayName == "2 Photos assets")
    }

    @Test func photosAlbumSelectionUsesAlbumNameForDisplay() {
        let selection = PhotosSelection(
            mode: .album(localIdentifier: "album-1", name: "Favorites"),
            representation: .current,
            allowsNetworkAccess: true
        )

        #expect(selection.displayName == "Favorites")
        #expect(selection.representation == .current)
        #expect(selection.allowsNetworkAccess)
    }
}
