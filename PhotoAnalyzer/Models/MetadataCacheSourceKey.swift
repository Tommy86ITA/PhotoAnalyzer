//
//  MetadataCacheSourceKey.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 27/06/2026.
//

import Foundation

/// Stable cache identity for ExifTool metadata extraction.
nonisolated struct MetadataCacheSourceKey: Hashable, Sendable {
    enum SourceKind: String, Sendable {
        case localFile
        case photosAsset
    }

    let kind: SourceKind
    let identifier: String
    let version: String

    static func photosAsset(
        localIdentifier: String,
        representation: PhotosAssetRepresentation,
        modificationDate: Date?
    ) -> MetadataCacheSourceKey {
        let modificationVersion = modificationDate
            .map { String($0.timeIntervalSince1970) }
            ?? "unknown"

        return MetadataCacheSourceKey(
            kind: .photosAsset,
            identifier: localIdentifier,
            version: "\(representation.rawValue):\(modificationVersion)"
        )
    }
}
