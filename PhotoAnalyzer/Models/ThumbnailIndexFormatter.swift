//
//  ThumbnailIndexFormatter.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 17/06/2026.
//

import Foundation

/// Stable formatter for contact sheet and metadata thumbnail indexes.
enum ThumbnailIndexFormatter {
    /// Formats a one-based thumbnail index for contact sheet labels and exports.
    /// - Parameter index: One-based thumbnail index.
    /// - Returns: A zero-padded index such as `001`.
    nonisolated static func string(from index: Int) -> String {
        String(format: "%03d", index)
    }
}
