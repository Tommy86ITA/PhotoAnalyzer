//
//  AIAnalysisPackageArchiver.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import Foundation
import ZIPFoundation

/// Progress snapshot emitted while archiving the generated AI package.
nonisolated struct ArchiveProgress: Sendable {
    let completedUnitCount: Int64
    let totalUnitCount: Int64
    let fractionCompleted: Double
}

/// Creates a ZIP archive for a generated AI analysis package.
final class AIAnalysisPackageArchiver {
    /// Creates an AI analysis package archiver.
    nonisolated init() {}

    /// Archives a generated package folder next to the package itself.
    /// - Parameters:
    ///   - packageURL: The generated package folder.
    ///   - archiveURL: The destination ZIP URL.
    ///   - progressHandler: Optional progress callback designed for future UI integration.
    /// - Returns: The created archive URL.
    /// - Throws: File system or archive creation errors.
    nonisolated func archivePackage(
        at packageURL: URL,
        to archiveURL: URL,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> URL {
        try Task.checkCancellation()

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: archiveURL.path) {
            try fileManager.removeItem(at: archiveURL)
        }

        let progress = Progress()
        progress.cancellationHandler = {
            progress.cancel()
        }

        try fileManager.zipItem(
            at: packageURL,
            to: archiveURL,
            shouldKeepParent: true,
            compressionMethod: .deflate,
            progress: progress
        )

        try Task.checkCancellation()

        progressHandler?(
            ArchiveProgress(
                completedUnitCount: progress.completedUnitCount,
                totalUnitCount: progress.totalUnitCount,
                fractionCompleted: progress.fractionCompleted
            )
        )

        print("AI package archive path: \(archiveURL.path)")
        return archiveURL
    }
}
