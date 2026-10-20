//
//  TemporaryAssetWorkspace.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Foundation
import OSLog

/// Owns a temporary directory used to materialize non-file sources as physical files.
final class TemporaryAssetWorkspace: @unchecked Sendable {
    nonisolated private static let baseDirectoryName = "PhotoAnalyzer"
    nonisolated private static let workspaceNamePrefix = "PhotosImport-"

    let directoryURL: URL

    nonisolated(unsafe) private var reservedFileNames: Set<String> = []
    nonisolated(unsafe) private let fileManager: FileManager

    nonisolated init(
        rootDirectoryURL: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager

        let baseDirectoryURL = Self.baseDirectoryURL(rootDirectoryURL: rootDirectoryURL)
        self.directoryURL = baseDirectoryURL
            .appendingPathComponent("\(Self.workspaceNamePrefix)\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    nonisolated func fileURL(preferredFilename: String?, fallbackBasename: String) -> URL {
        let fallbackFilename = fallbackBasename.isEmpty ? "asset" : fallbackBasename
        let sanitizedFilename = sanitizeFilename(preferredFilename ?? fallbackFilename)
        let filename = sanitizedFilename.isEmpty ? "\(fallbackFilename).dat" : sanitizedFilename
        let uniqueFilename = reserveUniqueFilename(filename)
        return directoryURL.appendingPathComponent(uniqueFilename, isDirectory: false)
    }

    nonisolated func cleanup() {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: directoryURL)
        } catch {
            AppLogger.analysis.error(
                "Temporary workspace cleanup failed at \(self.directoryURL.path, privacy: .private): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Captures workspaces left by a previous process before a new analysis can create one.
    nonisolated static func abandonedWorkspaceURLs(
        rootDirectoryURL: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default
    ) -> [URL] {
        let baseDirectoryURL = baseDirectoryURL(rootDirectoryURL: rootDirectoryURL)
        guard fileManager.fileExists(atPath: baseDirectoryURL.path) else {
            return []
        }

        do {
            return try fileManager.contentsOfDirectory(
                at: baseDirectoryURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ).filter { url in
                guard url.lastPathComponent.hasPrefix(workspaceNamePrefix) else {
                    return false
                }
                return try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
            }
        } catch {
            AppLogger.analysis.error(
                "Temporary workspace discovery failed: \(error.localizedDescription, privacy: .public)"
            )
            return []
        }
    }

    /// Removes only previously captured workspace directories inside PhotoAnalyzer's temporary root.
    nonisolated static func cleanupAbandonedWorkspaces(
        _ workspaceURLs: [URL],
        rootDirectoryURL: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default
    ) {
        let expectedParentURL = baseDirectoryURL(rootDirectoryURL: rootDirectoryURL).standardizedFileURL

        for workspaceURL in workspaceURLs {
            let standardizedURL = workspaceURL.standardizedFileURL
            guard standardizedURL.deletingLastPathComponent() == expectedParentURL,
                  standardizedURL.lastPathComponent.hasPrefix(workspaceNamePrefix) else {
                continue
            }

            do {
                try fileManager.removeItem(at: standardizedURL)
                AppLogger.analysis.info(
                    "Removed abandoned temporary workspace at \(standardizedURL.path, privacy: .private)"
                )
            } catch CocoaError.fileNoSuchFile {
                continue
            } catch {
                AppLogger.analysis.error(
                    "Abandoned workspace cleanup failed at \(standardizedURL.path, privacy: .private): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    nonisolated private static func baseDirectoryURL(rootDirectoryURL: URL) -> URL {
        rootDirectoryURL.appendingPathComponent(baseDirectoryName, isDirectory: true)
    }

    nonisolated private func reserveUniqueFilename(_ filename: String) -> String {
        let url = URL(fileURLWithPath: filename)
        let basename = url.deletingPathExtension().lastPathComponent
        let pathExtension = url.pathExtension
        var candidate = filename
        var suffix = 2

        while reservedFileNames.contains(candidate) {
            let suffixedBasename = "\(basename)-\(suffix)"
            candidate = pathExtension.isEmpty
                ? suffixedBasename
                : "\(suffixedBasename).\(pathExtension)"
            suffix += 1
        }

        reservedFileNames.insert(candidate)
        return candidate
    }

    nonisolated private func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
            .union(.newlines)
            .union(.controlCharacters)
        let components = filename.components(separatedBy: invalidCharacters)
        let sanitized = components.joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized
    }
}
