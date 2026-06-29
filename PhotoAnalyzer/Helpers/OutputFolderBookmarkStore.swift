//
//  OutputFolderBookmarkStore.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 20/06/2026.
//

import Foundation
import OSLog

/// Stores user-selected output folders in a form that can be resolved across launches.
enum OutputFolderBookmarkStore {
    static func bookmarkData(for folderURL: URL) throws -> Data {
        try folderURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    static func resolveBookmarkData(_ data: Data) -> URL? {
        guard !data.isEmpty else {
            return nil
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return isStale ? nil : url
        } catch {
            AppLogger.security.error("Failed to resolve output folder bookmark: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
