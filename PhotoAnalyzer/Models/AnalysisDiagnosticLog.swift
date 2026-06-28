//
//  AnalysisDiagnosticLog.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 28/06/2026.
//

import Foundation

/// Optional package artifact with operational details useful while diagnosing an analysis run.
nonisolated struct AnalysisDiagnosticLog: Encodable, Sendable {
    let generatedAt: String
    let datasetName: String
    let sourceFolderPath: String
    let packageFolderPath: String
    let supportedFileCount: Int
    let analyzedPhotoCount: Int
    let metadataRecordCount: Int
    let metadataCacheMaximumSizeMB: Int
    let metadataCacheHitCount: Int
    let metadataCacheMissCount: Int
    let outputFiles: [String]
}
