//
//  AnalysisSource.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Foundation

/// User-selected input source for analysis.
nonisolated enum AnalysisSource: Equatable, Sendable {
    case folder(FolderAnalysisSource)
    case photosLibrary(PhotosSelection)

    var displayName: String {
        switch self {
        case .folder(let source):
            source.folderURL.lastPathComponent
        case .photosLibrary(let selection):
            selection.displayName
        }
    }
}

/// Existing filesystem folder input.
nonisolated struct FolderAnalysisSource: Equatable, Sendable {
    let folderURL: URL
    let includeSubfolders: Bool
}
