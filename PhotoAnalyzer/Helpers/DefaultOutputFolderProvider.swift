//
//  DefaultOutputFolderProvider.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 20/06/2026.
//

import Foundation

/// Resolves and prepares the default user-visible folder for generated AI packages.
enum DefaultOutputFolderProvider {
    static let folderName = "PhotoAnalyzer"

    static func defaultOutputFolderURL(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName, isDirectory: true)
    }

    static func ensureOutputFolderExists(at url: URL, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }
}

