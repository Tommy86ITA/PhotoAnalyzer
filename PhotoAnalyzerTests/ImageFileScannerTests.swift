//
//  ImageFileScannerTests.swift
//  PhotoAnalyzerTests
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Foundation
import Testing
@testable import PhotoAnalyzer

struct ImageFileScannerTests {
    @Test func directScanReturnsSupportedFilesInStableNameOrder() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        try Data().write(to: directoryURL.appendingPathComponent("zeta.jpg"))
        try Data().write(to: directoryURL.appendingPathComponent("alpha.HEIC"))
        try Data().write(to: directoryURL.appendingPathComponent("notes.txt"))

        let fileNames = ImageFileScanner()
            .imageFileURLs(in: directoryURL)
            .map(\.lastPathComponent)

        #expect(fileNames == ["alpha.HEIC", "zeta.jpg"])
    }

    @Test func recursiveScanSkipsGeneratedPackageFoldersAndSymbolicLinks() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let nestedURL = directoryURL.appendingPathComponent("Nested", isDirectory: true)
        let packageURL = directoryURL.appendingPathComponent(AIAnalysisPackagePaths.folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: nestedURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

        let realImageURL = nestedURL.appendingPathComponent("real.png")
        let skippedPackageImageURL = packageURL.appendingPathComponent("generated.jpg")
        let symlinkURL = directoryURL.appendingPathComponent("linked.jpg")
        try Data().write(to: realImageURL)
        try Data().write(to: skippedPackageImageURL)
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: realImageURL)

        let fileNames = ImageFileScanner()
            .imageFileURLs(in: directoryURL, includeSubfolders: true)
            .map(\.lastPathComponent)

        #expect(fileNames == ["real.png"])
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}
