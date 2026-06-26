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

    @Test func photosSelectionCanAllowNetworkAccessForICloudOriginals() {
        let selection = PhotosSelection(
            mode: .assets(localIdentifiers: ["asset-1"]),
            allowsNetworkAccess: true
        )

        #expect(selection.allowsNetworkAccess)
        #expect(selection.displayName == "1 Photos asset")
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
        #expect(selection.networkAccessPolicy == .downloadMissingOriginals)
    }

    @Test func photosLibrarySelectionUsesLibraryDisplayName() {
        let selection = PhotosSelection(mode: .library)

        #expect(selection.displayName == "Photos Library")
        #expect(selection.representation == .original)
        #expect(selection.allowsNetworkAccess == false)
        #expect(selection.networkAccessPolicy == .localOnly)
    }

    @Test func photosNetworkAccessPolicyMapsToPhotoKitNetworkFlag() {
        #expect(PhotosNetworkAccessPolicy.localOnly.allowsNetworkAccess == false)
        #expect(PhotosNetworkAccessPolicy.downloadMissingOriginals.allowsNetworkAccess)
    }

    @Test func materializedPhotosAssetDisplayInfoUsesStablePhotosURI() {
        let asset = MaterializedPhotosAsset(
            assetLocalIdentifier: "ABCD/L0/001",
            originalFilename: "IMG_0001.HEIC",
            fileURL: URL(fileURLWithPath: "/tmp/materialized.heic"),
            representation: .original
        )

        #expect(asset.displayInfo.fileName == "IMG_0001.HEIC")
        #expect(asset.displayInfo.sourceFile == "photos://asset/ABCD%2FL0%2F001")
    }
}
