//
//  AnalysisUIState.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation

/// User-facing state for the current folder analysis.
enum AnalysisStatus {
    case ready
    case folderSelected
    case analyzing
    case cancelled
    case completed
    case completedWithExportError
    case failed

    var displayText: String {
        switch self {
        case .ready:
            return "Ready"
        case .folderSelected:
            return "Folder selected"
        case .analyzing:
            return "Analyzing"
        case .cancelled:
            return "Cancelled"
        case .completed:
            return "Completed"
        case .completedWithExportError:
            return "Completed with export error"
        case .failed:
            return "Failed"
        }
    }
}

/// Detailed operation phase shown in the status footer.
enum AnalysisPhase {
    case ready
    case noFolderSelected
    case noSupportedFiles
    case scanningFiles
    case readingMetadata
    case generatingStatistics
    case exportingAIPackage
    case generatingContactSheet
    case cancelled
    case completed
    case exportFailed
    case failed

    var displayText: String {
        switch self {
        case .ready:
            return "Ready"
        case .noFolderSelected:
            return "Select a folder first"
        case .noSupportedFiles:
            return "No supported files found"
        case .scanningFiles:
            return "Scanning files..."
        case .readingMetadata:
            return "Reading metadata..."
        case .generatingStatistics:
            return "Generating statistics..."
        case .exportingAIPackage:
            return "Exporting AI package..."
        case .generatingContactSheet:
            return "Generating contact sheet..."
        case .cancelled:
            return "Cancelled"
        case .completed:
            return "Package generated"
        case .exportFailed:
            return "Export failed"
        case .failed:
            return "Failed"
        }
    }
}

/// User-facing state for the latest AI analysis package.
enum PackageStatus {
    case notGenerated
    case generating
    case generated
    case failed

    var displayText: String {
        switch self {
        case .notGenerated:
            return "Not generated"
        case .generating:
            return "Generating"
        case .generated:
            return "Generated"
        case .failed:
            return "Export failed"
        }
    }
}

/// UI state describing the selected dataset.
struct DatasetUIState {
    var folderURL: URL?
    var supportedFileCount: Int?
    var analyzedPhotoCount: Int?
    var analysisStatus: AnalysisStatus

    static let initial = DatasetUIState(
        folderURL: nil,
        supportedFileCount: nil,
        analyzedPhotoCount: nil,
        analysisStatus: .ready
    )

    var folderPathText: String {
        folderURL?.path ?? "No folder selected"
    }

    var supportedFilesText: String {
        supportedFileCount.map(String.init) ?? "--"
    }

    var analyzedPhotosText: String {
        analyzedPhotoCount.map(String.init) ?? "--"
    }
}

/// UI state describing a generated AI analysis package.
struct AIPackageUIState {
    var status: PackageStatus
    var packageURL: URL?
    var metadataExists: Bool
    var statisticsExists: Bool
    var contactSheetExists: Bool
    var indexExists: Bool
    var errorMessage: String?

    static let initial = AIPackageUIState(
        status: .notGenerated,
        packageURL: nil,
        metadataExists: false,
        statisticsExists: false,
        contactSheetExists: false,
        indexExists: false,
        errorMessage: nil
    )

    init(
        status: PackageStatus,
        packageURL: URL?,
        metadataExists: Bool,
        statisticsExists: Bool,
        contactSheetExists: Bool,
        indexExists: Bool,
        errorMessage: String?
    ) {
        self.status = status
        self.packageURL = packageURL
        self.metadataExists = metadataExists
        self.statisticsExists = statisticsExists
        self.contactSheetExists = contactSheetExists
        self.indexExists = indexExists
        self.errorMessage = errorMessage
    }

    init(packageURL: URL, errorMessage: String? = nil) {
        let paths = AIAnalysisPackagePaths(packageURL: packageURL)
        self.init(
            status: errorMessage == nil ? .generated : .failed,
            packageURL: packageURL,
            metadataExists: FileManager.default.fileExists(atPath: paths.metadataURL.path),
            statisticsExists: FileManager.default.fileExists(atPath: paths.statisticsURL.path),
            contactSheetExists: FileManager.default.fileExists(atPath: paths.contactSheetURL.path),
            indexExists: FileManager.default.fileExists(atPath: paths.indexURL.path),
            errorMessage: errorMessage
        )
    }

    var packagePathText: String {
        packageURL?.path ?? "--"
    }
}
