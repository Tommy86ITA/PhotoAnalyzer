//
//  MetadataCacheSizeLimit.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 27/06/2026.
//

import Foundation

/// User-configurable size limits for the ExifTool metadata cache.
nonisolated enum MetadataCacheSizeLimit: Int, CaseIterable, Identifiable, Sendable {
    case off = 0
    case mb128 = 128
    case mb512 = 512
    case gb1 = 1024
    case gb2 = 2048

    var id: Int {
        rawValue
    }

    var byteCount: Int64 {
        Int64(rawValue) * 1_024 * 1_024
    }

    var displayName: String {
        switch self {
        case .off:
            return "Off"
        case .mb128:
            return "128 MB"
        case .mb512:
            return "512 MB"
        case .gb1:
            return "1 GB"
        case .gb2:
            return "2 GB"
        }
    }

    static func normalizedRawValue(_ rawValue: Int) -> Int {
        Self(rawValue: rawValue)?.rawValue ?? Self.mb512.rawValue
    }
}
