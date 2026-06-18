//
//  ImageFileScanner.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation

/// Scans folders for supported image files in a stable order.
final class ImageFileScanner {
    private let fileResourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isRegularFileKey,
        .isSymbolicLinkKey
    ]

    /// Creates an image file scanner.
    nonisolated init() {}

    /// Finds supported image files inside a folder.
    /// - Parameters:
    ///   - folderURL: The folder URL to inspect.
    ///   - includeSubfolders: Whether subfolders should be scanned recursively.
    ///   - expectedSupportedFileCount: Optional known total of supported files.
    ///   - progressHandler: Optional progress callback for scanned file candidates.
    /// - Returns: Supported image file URLs sorted by relative path.
    nonisolated func imageFileURLs(
        in folderURL: URL,
        includeSubfolders: Bool = false,
        expectedSupportedFileCount: Int? = nil,
        progressHandler: (@Sendable (ProgressSnapshot) -> Void)? = nil
    ) -> [URL] {
        if includeSubfolders {
            return recursiveImageFileURLs(
                in: folderURL,
                expectedSupportedFileCount: expectedSupportedFileCount,
                progressHandler: progressHandler
            )
        }

        return directImageFileURLs(
            in: folderURL,
            expectedSupportedFileCount: expectedSupportedFileCount,
            progressHandler: progressHandler
        )
    }

    /// Finds supported image files directly inside a folder.
    /// - Parameter folderURL: The folder URL to inspect.
    /// - Returns: Supported image file URLs sorted by file name.
    nonisolated private func directImageFileURLs(
        in folderURL: URL,
        expectedSupportedFileCount: Int?,
        progressHandler: (@Sendable (ProgressSnapshot) -> Void)?
    ) -> [URL] {
        let fileURLs = (try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(fileResourceKeys),
            options: [.skipsHiddenFiles]
        )) ?? []

        var supportedFileURLs: [URL] = []
        let sortedFileURLs = fileURLs.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        let candidateCount = Int64(sortedFileURLs.count)
        let supportedTotalCount = expectedSupportedFileCount.map(Int64.init)

        for (offset, fileURL) in sortedFileURLs.enumerated() {
            guard !Task.isCancelled else {
                return supportedFileURLs
            }

            let resourceValues = try? fileURL.resourceValues(forKeys: fileResourceKeys)
            let isRegularFile = resourceValues?.isRegularFile ?? false
            let isSymbolicLink = resourceValues?.isSymbolicLink ?? false

            guard !isSymbolicLink else {
                continue
            }

            guard isRegularFile else {
                continue
            }

            if SupportedImageFormats.contains(fileURL) {
                print("File discovered: \(fileURL.lastPathComponent)")
                supportedFileURLs.append(fileURL)
                emitScanProgress(
                    completedCandidateCount: Int64(offset + 1),
                    candidateCount: candidateCount,
                    discoveredSupportedCount: Int64(supportedFileURLs.count),
                    expectedSupportedFileCount: supportedTotalCount,
                    progressHandler: progressHandler
                )
            } else {
                print("File skipped because unsupported extension: \(fileURL.lastPathComponent)")
                emitScanProgress(
                    completedCandidateCount: Int64(offset + 1),
                    candidateCount: candidateCount,
                    discoveredSupportedCount: Int64(supportedFileURLs.count),
                    expectedSupportedFileCount: supportedTotalCount,
                    progressHandler: progressHandler
                )
            }
        }

        return supportedFileURLs
    }

    /// Finds supported image files recursively, skipping generated package folders and symlinks.
    /// - Parameter folderURL: The folder URL to inspect.
    /// - Returns: Supported image file URLs sorted by path relative to `folderURL`.
    nonisolated private func recursiveImageFileURLs(
        in folderURL: URL,
        expectedSupportedFileCount: Int?,
        progressHandler: (@Sendable (ProgressSnapshot) -> Void)?
    ) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: Array(fileResourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var supportedFileURLs: [URL] = []
        var scannedCount: Int64 = 0
        let supportedTotalCount = expectedSupportedFileCount.map(Int64.init)

        for case let fileURL as URL in enumerator {
            guard !Task.isCancelled else {
                return supportedFileURLs.sorted {
                    relativePath(for: $0, relativeTo: folderURL)
                        .localizedStandardCompare(relativePath(for: $1, relativeTo: folderURL)) == .orderedAscending
                }
            }

            scannedCount += 1

            let resourceValues = try? fileURL.resourceValues(forKeys: fileResourceKeys)
            let isSymbolicLink = resourceValues?.isSymbolicLink ?? false

            guard !isSymbolicLink else {
                continue
            }

            if resourceValues?.isDirectory == true {
                if shouldSkipDirectory(fileURL) {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard resourceValues?.isRegularFile == true else {
                continue
            }

            if SupportedImageFormats.contains(fileURL) {
                print("File discovered: \(relativePath(for: fileURL, relativeTo: folderURL))")
                supportedFileURLs.append(fileURL)
                emitScanProgress(
                    completedCandidateCount: scannedCount,
                    candidateCount: 0,
                    discoveredSupportedCount: Int64(supportedFileURLs.count),
                    expectedSupportedFileCount: supportedTotalCount,
                    progressHandler: progressHandler
                )
            } else {
                print("File skipped because unsupported extension: \(relativePath(for: fileURL, relativeTo: folderURL))")
                emitScanProgress(
                    completedCandidateCount: scannedCount,
                    candidateCount: 0,
                    discoveredSupportedCount: Int64(supportedFileURLs.count),
                    expectedSupportedFileCount: supportedTotalCount,
                    progressHandler: progressHandler
                )
            }
        }

        return supportedFileURLs.sorted {
            relativePath(for: $0, relativeTo: folderURL)
                .localizedStandardCompare(relativePath(for: $1, relativeTo: folderURL)) == .orderedAscending
        }
    }

    /// Emits scan progress using the known supported-file total when available.
    nonisolated private func emitScanProgress(
        completedCandidateCount: Int64,
        candidateCount: Int64,
        discoveredSupportedCount: Int64,
        expectedSupportedFileCount: Int64?,
        progressHandler: (@Sendable (ProgressSnapshot) -> Void)?
    ) {
        if let expectedSupportedFileCount, expectedSupportedFileCount > 0 {
            progressHandler?(
                ProgressSnapshot(
                    completedUnitCount: min(discoveredSupportedCount, expectedSupportedFileCount),
                    totalUnitCount: expectedSupportedFileCount,
                    message: "Scanning files..."
                )
            )
            return
        }

        progressHandler?(
            ProgressSnapshot(
                completedUnitCount: completedCandidateCount,
                totalUnitCount: candidateCount,
                message: "Scanning files..."
            )
        )
    }

    /// Returns whether a directory should be excluded from recursive scans.
    /// - Parameter url: The directory URL to inspect.
    /// - Returns: `true` when the directory is generated by PhotoAnalyzer.
    nonisolated private func shouldSkipDirectory(_ url: URL) -> Bool {
        let folderName = url.lastPathComponent
        return folderName == AIAnalysisPackagePaths.folderName
            || folderName.contains("_\(AIAnalysisPackagePaths.folderName)_")
    }

    /// Builds a stable display/sort path relative to the selected dataset folder.
    /// - Parameters:
    ///   - url: The discovered file URL.
    ///   - folderURL: The selected dataset folder URL.
    /// - Returns: A path relative to the selected folder when possible.
    nonisolated private func relativePath(for url: URL, relativeTo folderURL: URL) -> String {
        let folderPath = folderURL.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        let prefix = folderPath.hasSuffix("/") ? folderPath : "\(folderPath)/"

        guard filePath.hasPrefix(prefix) else {
            return url.lastPathComponent
        }

        return String(filePath.dropFirst(prefix.count))
    }
}
