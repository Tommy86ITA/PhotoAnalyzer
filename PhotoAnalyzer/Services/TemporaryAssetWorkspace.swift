//
//  TemporaryAssetWorkspace.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Foundation

/// Owns a temporary directory used to materialize non-file sources as physical files.
final class TemporaryAssetWorkspace {
    let directoryURL: URL

    private var reservedFileNames: Set<String> = []
    private let fileManager: FileManager

    init(
        rootDirectoryURL: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager

        let baseDirectoryURL = rootDirectoryURL
            .appendingPathComponent("PhotoAnalyzer", isDirectory: true)
        self.directoryURL = baseDirectoryURL
            .appendingPathComponent("PhotosImport-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    func fileURL(preferredFilename: String?, fallbackBasename: String) -> URL {
        let fallbackFilename = fallbackBasename.isEmpty ? "asset" : fallbackBasename
        let sanitizedFilename = sanitizeFilename(preferredFilename ?? fallbackFilename)
        let filename = sanitizedFilename.isEmpty ? "\(fallbackFilename).dat" : sanitizedFilename
        let uniqueFilename = reserveUniqueFilename(filename)
        return directoryURL.appendingPathComponent(uniqueFilename, isDirectory: false)
    }

    func cleanup() {
        try? fileManager.removeItem(at: directoryURL)
    }

    private func reserveUniqueFilename(_ filename: String) -> String {
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

    private func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
            .union(.newlines)
            .union(.controlCharacters)
        let components = filename.components(separatedBy: invalidCharacters)
        let sanitized = components.joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized
    }
}
