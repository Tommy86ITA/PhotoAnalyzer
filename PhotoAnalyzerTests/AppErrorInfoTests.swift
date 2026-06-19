//
//  AppErrorInfoTests.swift
//  PhotoAnalyzerTests
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Testing
@testable import PhotoAnalyzer

struct AppErrorInfoTests {
    @Test func photosSkippedAssetsReturnsNilForEmptyFailures() {
        #expect(AppErrorInfo.photosSkippedAssets([]) == nil)
    }

    @Test func photosSkippedAssetsBuildsUserWarningAndDebugDetails() throws {
        let warning = try #require(AppErrorInfo.photosSkippedAssets([
            PhotosAssetExportFailure(
                assetLocalIdentifier: "asset-1",
                reason: "The resource requires network access."
            ),
            PhotosAssetExportFailure(
                assetLocalIdentifier: "asset-2",
                reason: "Asset was not found in the Photos Library."
            )
        ]))

        #expect(warning.userMessage == "2 Photos assets skipped. Some originals may be unavailable locally.")
        #expect(warning.debugDescription.contains("asset-1: The resource requires network access."))
        #expect(warning.debugDescription.contains("asset-2: Asset was not found in the Photos Library."))
    }
}
