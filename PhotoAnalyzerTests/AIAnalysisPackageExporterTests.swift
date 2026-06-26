//
//  AIAnalysisPackageExporterTests.swift
//  PhotoAnalyzerTests
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Foundation
import Testing
@testable import PhotoAnalyzer

struct AIAnalysisPackageExporterTests {
    @Test func exportDataFilesUsesDisplayInfoForMaterializedSources() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let sourceURL = directoryURL.appendingPathComponent("materialized.jpg")
        let metadataJSON = """
        {
          "SourceFile": "\(sourceURL.path)",
          "File:FileName": "materialized.jpg",
          "File:FileType": "JPEG"
        }
        """.data(using: .utf8)!
        let metadata = try JSONDecoder().decode(ExportPhotoMetadata.self, from: metadataJSON)
        let statistics = PhotoStatistics(
            totalPhotos: 1,
            photosByType: [.standard: 1],
            photosByCamera: [:],
            isoDistribution: [:],
            focalLength35mmDistribution: [:],
            apertureDistribution: [:],
            shutterSpeedDistribution: [:],
            lensDistribution: [:],
            averageISO: nil,
            averageFocalLength35mmEquivalent: nil
        )
        let paths = AIAnalysisPackagePaths(packageURL: directoryURL.appendingPathComponent("Package"))
        let displayInfo = SourceFileDisplayInfo(
            fileName: "IMG_0001.HEIC",
            sourceFile: "photos://asset/local-id-1"
        )

        _ = try AIAnalysisPackageExporter().exportDataFiles(
            for: directoryURL,
            metadata: [metadata],
            sourceFileURLs: [sourceURL],
            statistics: statistics,
            paths: paths,
            displayInfoByFileURL: [sourceURL: displayInfo],
            progressHandler: nil
        )

        let data = try Data(contentsOf: paths.metadataURL)
        let payload = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let firstRecord = try #require(payload.first)

        #expect(firstRecord["File:FileName"] as? String == "IMG_0001.HEIC")
        #expect(firstRecord["SourceFile"] as? String == "photos://asset/local-id-1")
        #expect(firstRecord["ThumbnailIndex"] as? String == "001")
    }
}
