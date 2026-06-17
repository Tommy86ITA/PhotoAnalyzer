//
//  ImageFileScanner.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation

/// Scans folders for supported image files in a stable order.
final class ImageFileScanner {
    /// Creates an image file scanner.
    nonisolated init() {}

    /// Finds supported image files directly inside a folder.
    /// - Parameter folderURL: The folder URL to inspect.
    /// - Returns: Supported image file URLs sorted by file name.
    nonisolated func imageFileURLs(in folderURL: URL) -> [URL] {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        let fileURLs = (try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        )) ?? []

        var supportedFileURLs: [URL] = []
        let sortedFileURLs = fileURLs.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }

        for fileURL in sortedFileURLs {
            let isRegularFile = (try? fileURL.resourceValues(forKeys: resourceKeys).isRegularFile) ?? false
            guard isRegularFile else {
                continue
            }

            if SupportedImageFormats.contains(fileURL) {
                print("File discovered: \(fileURL.lastPathComponent)")
                supportedFileURLs.append(fileURL)
            } else {
                print("File skipped because unsupported extension: \(fileURL.lastPathComponent)")
            }
        }

        return supportedFileURLs
    }
}
