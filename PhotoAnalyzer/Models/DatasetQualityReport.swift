//
//  DatasetQualityReport.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 28/06/2026.
//

import Foundation

/// Optional package artifact that summarizes metadata completeness for an analyzed dataset.
nonisolated struct DatasetQualityReport: Encodable, Sendable {
    let generatedAt: String
    let analyzedPhotoCount: Int
    let metadataRecordCount: Int
    let issueCounts: DatasetQualityIssueCounts
    let issueSamples: [DatasetQualityIssueSample]
}

/// Aggregate counts for common metadata gaps.
nonisolated struct DatasetQualityIssueCounts: Encodable, Sendable {
    let missingCaptureDate: Int
    let missingGpsLocation: Int
    let missingCameraModel: Int
    let missingLensModel: Int
    let missingExposureSettings: Int
}

/// A capped sample of files that contributed to the quality report issue counts.
nonisolated struct DatasetQualityIssueSample: Encodable, Sendable {
    let thumbnailIndex: String
    let fileName: String
    let sourceFile: String?
    let issues: [String]
}
