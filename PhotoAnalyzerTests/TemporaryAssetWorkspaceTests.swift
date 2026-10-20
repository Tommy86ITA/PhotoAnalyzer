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

    @Test func abandonedWorkspaceDiscoveryIgnoresUnrelatedItems() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let baseURL = rootURL.appendingPathComponent("PhotoAnalyzer", isDirectory: true)
        let abandonedURL = baseURL.appendingPathComponent("PhotosImport-abandoned", isDirectory: true)
        let unrelatedURL = baseURL.appendingPathComponent("OtherData", isDirectory: true)
        let matchingFileURL = baseURL.appendingPathComponent("PhotosImport-not-a-directory")
        try FileManager.default.createDirectory(at: abandonedURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unrelatedURL, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: matchingFileURL.path, contents: Data())
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let discoveredURLs = TemporaryAssetWorkspace.abandonedWorkspaceURLs(rootDirectoryURL: rootURL)

        #expect(discoveredURLs == [abandonedURL])
    }

    @Test func abandonedWorkspaceCleanupRemovesOnlyCapturedWorkspaces() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let baseURL = rootURL.appendingPathComponent("PhotoAnalyzer", isDirectory: true)
        let abandonedURL = baseURL.appendingPathComponent("PhotosImport-abandoned", isDirectory: true)
        let unrelatedURL = baseURL.appendingPathComponent("OtherData", isDirectory: true)
        try FileManager.default.createDirectory(at: abandonedURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unrelatedURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let capturedURLs = TemporaryAssetWorkspace.abandonedWorkspaceURLs(rootDirectoryURL: rootURL)
        let currentWorkspace = try TemporaryAssetWorkspace(rootDirectoryURL: rootURL)
        defer {
            currentWorkspace.cleanup()
        }

        TemporaryAssetWorkspace.cleanupAbandonedWorkspaces(
            capturedURLs,
            rootDirectoryURL: rootURL
        )
        TemporaryAssetWorkspace.cleanupAbandonedWorkspaces(
            capturedURLs,
            rootDirectoryURL: rootURL
        )

        #expect(!FileManager.default.fileExists(atPath: abandonedURL.path))
        #expect(FileManager.default.fileExists(atPath: unrelatedURL.path))
        #expect(FileManager.default.fileExists(atPath: currentWorkspace.directoryURL.path))
    }
}
