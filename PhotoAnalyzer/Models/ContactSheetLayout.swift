//
//  ContactSheetLayout.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import CoreGraphics
import Foundation

/// Shared contact sheet layout rules used by image export and metadata indexing.
nonisolated enum ContactSheetLayout {
    static let smallDatasetMaximumPhotoCount = 100
    static let mediumDatasetMaximumPhotoCount = 300
    static let largeDatasetMaximumPhotoCount = 600
    static let smallDatasetColumns = 5
    static let mediumDatasetColumns = 6
    static let largeDatasetColumns = 8
    static let extraLargeDatasetColumns = 10
    static let maxConcurrentThumbnailLoads = 6
    static let thumbnailSize = CGSize(width: 512, height: 384)
    static let labelHeight: CGFloat = 26
    static let padding: CGFloat = 24
    static let spacing: CGFloat = 16
    static let maximumRowsPerSheet = 25
    static let maximumJPEGDimension: CGFloat = 65_000
    static let jpegCompressionQuality = 0.75

    static func columnCount(for photoCount: Int) -> Int {
        switch photoCount {
        case ...smallDatasetMaximumPhotoCount:
            smallDatasetColumns
        case ...mediumDatasetMaximumPhotoCount:
            mediumDatasetColumns
        case ...largeDatasetMaximumPhotoCount:
            largeDatasetColumns
        default:
            extraLargeDatasetColumns
        }
    }

    static func pageFileName(_ pageNumber: Int) -> String {
        let formattedPageNumber = String(format: "%03d", pageNumber)
        return "contact_sheet_\(formattedPageNumber).jpg"
    }
}
