//
//  AIAnalysisPackagePaths.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation

/// File locations for a PhotoAnalyzer AI analysis package.
nonisolated struct AIAnalysisPackagePaths {
    static let folderName = "PhotoAnalyzer_AI_Package"

    let packageURL: URL

    init(folderURL: URL) {
        packageURL = folderURL.appendingPathComponent(Self.folderName, isDirectory: true)
    }

    init(packageURL: URL) {
        self.packageURL = packageURL
    }

    var metadataURL: URL {
        packageURL.appendingPathComponent("metadata.json")
    }

    var statisticsURL: URL {
        packageURL.appendingPathComponent("statistics.json")
    }

    var contactSheetURL: URL {
        packageURL.appendingPathComponent("contact_sheet.jpg")
    }

    var indexURL: URL {
        packageURL.appendingPathComponent("index.tsv")
    }
}
