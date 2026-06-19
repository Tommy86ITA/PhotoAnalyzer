//
//  ContactSheetExportModels.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import Foundation

nonisolated struct SourceFileDisplayInfo: Equatable, Sendable {
    let fileName: String
    let sourceFile: String
}

nonisolated struct ContactSheetIndexRow {
    let index: String
    let sheet: String
    let fileName: String
    let sourceFile: String
    let row: Int
    let column: Int
    let error: String?
}

nonisolated struct IndexedThumbnailResult {
    let index: Int
    let fileURL: URL
    let displayInfo: SourceFileDisplayInfo?
    let thumbnail: ThumbnailLoadResult?
}

nonisolated struct ThumbnailDrawResult {
    let status: ThumbnailStatus
    let error: String?
}

nonisolated struct ContactSheetPageRenderResult {
    let indexRows: [ContactSheetIndexRow]
    let summary: ContactSheetExportSummary
}

nonisolated struct ContactSheetExportSummary {
    private(set) var quickLookCount = 0
    private(set) var nsImageCount = 0
    private(set) var cgImageSourceCount = 0
    private(set) var unavailableCount = 0

    mutating func record(_ status: ThumbnailStatus) {
        switch status {
        case .quickLook:
            quickLookCount += 1
        case .nsImage:
            nsImageCount += 1
        case .cgImageSource:
            cgImageSourceCount += 1
        case .unavailable:
            unavailableCount += 1
        }
    }

    mutating func merge(_ other: ContactSheetExportSummary) {
        quickLookCount += other.quickLookCount
        nsImageCount += other.nsImageCount
        cgImageSourceCount += other.cgImageSourceCount
        unavailableCount += other.unavailableCount
    }

    var logMessage: String {
        "Contact sheet thumbnails: QuickLook=\(quickLookCount), NSImage=\(nsImageCount), CGImageSource=\(cgImageSourceCount), unavailable=\(unavailableCount)"
    }
}

nonisolated enum ContactSheetExporterError: LocalizedError {
    case couldNotCreateBitmapContext
    case couldNotCreateImage
    case couldNotCreateJPEGDestination
    case couldNotWriteJPEG(String)
    case contactSheetTooLarge(Int)
    case contactSheetPageTooLarge(String)

    var errorDescription: String? {
        switch self {
        case .couldNotCreateBitmapContext:
            return "Could not create the contact sheet bitmap context."
        case .couldNotCreateImage:
            return "Could not create the contact sheet image."
        case .couldNotCreateJPEGDestination:
            return "Could not create the contact sheet JPEG destination."
        case .couldNotWriteJPEG(let path):
            return "Could not write contact sheet JPEG at \(path)."
        case .contactSheetTooLarge(let photoCount):
            return "The contact sheet is too large for a single JPEG with \(photoCount) photos."
        case .contactSheetPageTooLarge(let fileName):
            return "The contact sheet page \(fileName) is too large for a JPEG."
        }
    }
}
