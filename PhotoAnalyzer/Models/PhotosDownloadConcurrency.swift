//
//  PhotosDownloadConcurrency.swift
//  PhotoAnalyzer
//
//  Created by Codex on 20/10/2026.
//

import Foundation

/// Supported limits for concurrent iCloud Photos resource downloads.
nonisolated enum PhotosDownloadConcurrency {
    static let minimum = 1
    static let recommended = 3
    static let warningThreshold = 5
    static let maximum = 6
    static let allowedRange = minimum...maximum

    static func clamped(_ value: Int) -> Int {
        min(max(value, minimum), maximum)
    }
}
