//
//  AIAnalysisPackageArchiver.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import Foundation
import OSLog
import ZIPFoundation

/// Creates a ZIP archive for a generated AI analysis package.
final class AIAnalysisPackageArchiver {
    private let progressResolution: Int64 = 1_000

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
        progressHandler: (@Sendable (ProgressSnapshot) -> Void)? = nil
    ) throws -> URL {
        try Task.checkCancellation()
        progressHandler?(
            ProgressSnapshot(
                completedUnitCount: 0,
                totalUnitCount: 1,
                message: "Archiving package..."
            )
        )

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: archiveURL.path) {
            try fileManager.removeItem(at: archiveURL)
        }

        let progress = Progress()
        progress.cancellationHandler = {
            progress.cancel()
        }
        let progressObservation = progress.observe(\.fractionCompleted, options: [.new]) { progress, _ in
            progressHandler?(
                ProgressSnapshot(
                    completedUnitCount: Int64((progress.fractionCompleted * Double(self.progressResolution)).rounded()),
                    totalUnitCount: self.progressResolution,
                    message: "Archiving package..."
                )
            )
        }
        defer {
            progressObservation.invalidate()
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
            ProgressSnapshot(
                completedUnitCount: 1,
                totalUnitCount: 1,
                message: "Archive ready"
            )
        )

        AppLogger.export.info("AI package archive path: \(archiveURL.path, privacy: .private)")
        return archiveURL
    }
}
