//
//  PhotosAlbumSummary.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 26/06/2026.
//

import Foundation

/// Lightweight album information used by the Photos Library source picker.
nonisolated struct PhotosAlbumSummary: Identifiable, Equatable, Sendable {
    let localIdentifier: String
    let title: String
    let imageAssetCount: Int

    var id: String {
        localIdentifier
    }
}
