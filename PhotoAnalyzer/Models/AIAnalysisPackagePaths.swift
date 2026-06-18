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
    static let metadataFileName = "metadata.json"
    static let statisticsFileName = "statistics.json"
    static let contactSheetFileName = "contact_sheet.jpg"
    static let indexFileName = "index.tsv"

    let packageURL: URL

    init(folderURL: URL) {
        packageURL = folderURL.appendingPathComponent(Self.folderName, isDirectory: true)
    }

    init(datasetFolderURL: URL, outputFolderURL: URL?, createdAt: Date = Date()) {
        if let outputFolderURL {
            let datasetName = Self.sanitizedFolderName(from: datasetFolderURL.lastPathComponent)
            let timestamp = Self.timestampFormatter.string(from: createdAt)
            let packageFolderName = "\(datasetName)_\(Self.folderName)_\(timestamp)"
            packageURL = outputFolderURL.appendingPathComponent(packageFolderName, isDirectory: true)
        } else {
            packageURL = datasetFolderURL.appendingPathComponent(Self.folderName, isDirectory: true)
        }
    }

    init(packageURL: URL) {
        self.packageURL = packageURL
    }

    var metadataURL: URL {
        packageURL.appendingPathComponent(Self.metadataFileName)
    }

    var statisticsURL: URL {
        packageURL.appendingPathComponent(Self.statisticsFileName)
    }

    var contactSheetURL: URL {
        packageURL.appendingPathComponent(Self.contactSheetFileName)
    }

    var indexURL: URL {
        packageURL.appendingPathComponent(Self.indexFileName)
    }

    var archiveURL: URL {
        packageURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(packageURL.lastPathComponent).zip")
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private static func sanitizedFolderName(from rawName: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let sanitizedScalars = rawName.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? Character(scalar) : "_"
        }

        let sanitizedName = String(sanitizedScalars)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " _-"))

        return sanitizedName.isEmpty ? "Dataset" : sanitizedName
    }
}
