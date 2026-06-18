//
//  SupportedFileCountService.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import Foundation

/// Counts supported image files while owning the filesystem access details.
nonisolated struct SupportedFileCountService: Sendable {
    func countSupportedFiles(in folderURL: URL, includeSubfolders: Bool) -> Int {
        let accessGranted = folderURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        return ImageFileScanner()
            .imageFileURLs(in: folderURL, includeSubfolders: includeSubfolders)
            .count
    }
}
