//
//  PhotosSelection.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Foundation

/// A Photos Library selection that can later be materialized into temporary files.
nonisolated struct PhotosSelection: Equatable, Sendable {
    let mode: PhotosSelectionMode
    let representation: PhotosAssetRepresentation
    let networkAccessPolicy: PhotosNetworkAccessPolicy

    var allowsNetworkAccess: Bool {
        networkAccessPolicy.allowsNetworkAccess
    }

    init(
        mode: PhotosSelectionMode,
        representation: PhotosAssetRepresentation = .original,
        networkAccessPolicy: PhotosNetworkAccessPolicy = .localOnly
    ) {
        self.mode = mode
        self.representation = representation
        self.networkAccessPolicy = networkAccessPolicy
    }

    init(
        mode: PhotosSelectionMode,
        representation: PhotosAssetRepresentation = .original,
        allowsNetworkAccess: Bool
    ) {
        self.init(
            mode: mode,
            representation: representation,
            networkAccessPolicy: allowsNetworkAccess ? .downloadMissingOriginals : .localOnly
        )
    }

    var displayName: String {
        switch mode {
        case .assets(let localIdentifiers):
            if localIdentifiers.count == 1 {
                return "1 Photos asset"
            }
            return "\(localIdentifiers.count) Photos assets"
        case .album(_, let name):
            return name ?? "Photos album"
        case .library:
            return "Photos Library"
        }
    }
}

/// Supported Photos Library selection scopes.
nonisolated enum PhotosSelectionMode: Equatable, Sendable {
    case assets(localIdentifiers: [String])
    case album(localIdentifier: String, name: String?)
    case library
}

/// Which Photos representation should be exported before file-based analysis.
nonisolated enum PhotosAssetRepresentation: String, Equatable, Sendable {
    case original
    case current
}

/// Whether Photos materialization may download missing iCloud originals.
nonisolated enum PhotosNetworkAccessPolicy: String, Equatable, Sendable {
    case localOnly
    case downloadMissingOriginals

    var allowsNetworkAccess: Bool {
        self == .downloadMissingOriginals
    }
}
