//
//  TemporaryAssetWorkspaceTests.swift
//  PhotoAnalyzerTests
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Foundation
import Testing
@testable import PhotoAnalyzer

struct TemporaryAssetWorkspaceTests {
    @Test func workspaceCreatesAndCleansTemporaryDirectory() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let workspace = try TemporaryAssetWorkspace(rootDirectoryURL: rootURL)

        #expect(FileManager.default.fileExists(atPath: workspace.directoryURL.path))

        workspace.cleanup()

        #expect(!FileManager.default.fileExists(atPath: workspace.directoryURL.path))
    }

    @Test func workspaceSanitizesAndDeduplicatesFilenames() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let workspace = try TemporaryAssetWorkspace(rootDirectoryURL: rootURL)
        defer {
            workspace.cleanup()
        }

        let firstURL = workspace.fileURL(
            preferredFilename: "Trip:Day/One?.jpg",
            fallbackBasename: "fallback"
        )
        let secondURL = workspace.fileURL(
            preferredFilename: "Trip:Day/One?.jpg",
            fallbackBasename: "fallback"
        )

        #expect(firstURL.lastPathComponent == "Trip_Day_One_.jpg")
        #expect(secondURL.lastPathComponent == "Trip_Day_One_-2.jpg")
    }
}
