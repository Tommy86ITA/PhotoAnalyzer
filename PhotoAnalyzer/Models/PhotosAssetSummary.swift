//
//  PhotosAssetSummary.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 26/06/2026.
//

import Foundation

/// Lightweight PhotoKit asset information used by the custom Photos picker.
nonisolated struct PhotosAssetSummary: Identifiable, Equatable, Sendable {
    let localIdentifier: String
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    let searchText: String

    var id: String {
        localIdentifier
    }
}
