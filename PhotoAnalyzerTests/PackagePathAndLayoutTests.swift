//
//  PackagePathAndLayoutTests.swift
//  PhotoAnalyzerTests
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Foundation
import Testing
@testable import PhotoAnalyzer

struct PackagePathAndLayoutTests {
    @Test func packagePathsUseDatasetFolderWhenNoOutputFolderIsSelected() {
        let datasetURL = URL(fileURLWithPath: "/tmp/My Dataset", isDirectory: true)
        let paths = AIAnalysisPackagePaths(datasetFolderURL: datasetURL, outputFolderURL: nil)

        #expect(paths.packageURL.path == "/tmp/My Dataset/PhotoAnalyzer_AI_Package")
        #expect(paths.metadataURL.lastPathComponent == "metadata.json")
        #expect(paths.statisticsURL.lastPathComponent == "statistics.json")
        #expect(paths.contactSheetURL.lastPathComponent == "contact_sheet.jpg")
        #expect(paths.indexURL.lastPathComponent == "index.tsv")
        #expect(paths.archiveURL.path == "/tmp/My Dataset/PhotoAnalyzer_AI_Package.zip")
    }

    @Test func packagePathsSanitizeDatasetNameForExternalOutputFolder() throws {
        let datasetURL = URL(fileURLWithPath: "/tmp/New/York: Trip?", isDirectory: true)
        let outputURL = URL(fileURLWithPath: "/exports", isDirectory: true)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let createdAt = try #require(calendar.date(
            from: DateComponents(year: 2024, month: 1, day: 1, hour: 0, minute: 0, second: 0)
        ))

        let paths = AIAnalysisPackagePaths(
            datasetFolderURL: datasetURL,
            outputFolderURL: outputURL,
            createdAt: createdAt
        )

        #expect(paths.packageURL.lastPathComponent == "York_ Trip_PhotoAnalyzer_AI_Package_20240101-000000")
        #expect(paths.archiveURL.lastPathComponent == "York_ Trip_PhotoAnalyzer_AI_Package_20240101-000000.zip")
    }

    @Test func contactSheetLayoutSelectsColumnsAndPageNames() {
        #expect(ContactSheetLayout.columnCount(for: 1) == 5)
        #expect(ContactSheetLayout.columnCount(for: 100) == 5)
        #expect(ContactSheetLayout.columnCount(for: 101) == 6)
        #expect(ContactSheetLayout.columnCount(for: 301) == 8)
        #expect(ContactSheetLayout.columnCount(for: 601) == 10)
        #expect(ContactSheetLayout.pageFileName(7) == "contact_sheet_007.jpg")
    }
}
