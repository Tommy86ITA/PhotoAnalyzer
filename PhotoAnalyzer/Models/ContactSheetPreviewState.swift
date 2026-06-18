//
//  ContactSheetPreviewState.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import AppKit
import Foundation

/// UI state for browsing generated contact sheet pages.
@MainActor
struct ContactSheetPreviewState {
    var image: NSImage?
    var pageURLs: [URL] = []
    var currentPageIndex = 0

    var pageCount: Int {
        pageURLs.count
    }

    var canOpenViewer: Bool {
        !pageURLs.isEmpty
    }

    mutating func reset() {
        image = nil
        pageURLs = []
        currentPageIndex = 0
    }

    mutating func load(from packageURL: URL) {
        pageURLs = Self.discoverPages(in: packageURL)
        currentPageIndex = 0
        loadPage(at: currentPageIndex)
    }

    mutating func showPreviousPage() {
        loadPage(at: max(0, currentPageIndex - 1))
    }

    mutating func showNextPage() {
        guard !pageURLs.isEmpty else {
            return
        }

        loadPage(at: min(pageURLs.count - 1, currentPageIndex + 1))
    }

    private mutating func loadPage(at index: Int) {
        guard pageURLs.indices.contains(index) else {
            image = nil
            return
        }

        currentPageIndex = index
        image = NSImage(contentsOf: pageURLs[index])
    }

    private nonisolated static func discoverPages(in packageURL: URL) -> [URL] {
        let paths = AIAnalysisPackagePaths(packageURL: packageURL)
        let fileManager = FileManager.default
        let pageURLs = (try? fileManager.contentsOfDirectory(
            at: packageURL,
            includingPropertiesForKeys: nil
        ))?
            .filter { url in
                let fileName = url.lastPathComponent
                return fileName.hasPrefix("contact_sheet_") && fileName.hasSuffix(".jpg")
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending } ?? []

        if !pageURLs.isEmpty {
            return pageURLs
        }

        guard fileManager.fileExists(atPath: paths.contactSheetURL.path) else {
            return []
        }

        return [paths.contactSheetURL]
    }
}
