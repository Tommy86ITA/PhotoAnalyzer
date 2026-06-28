//
//  AnalysisDiagnosticLogService.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 28/06/2026.
//

import Foundation

/// Builds the optional diagnostic log exported with an AI package.
nonisolated struct AnalysisDiagnosticLogService {
    func makeLog(
        sourceFolderURL: URL,
        paths: AIAnalysisPackagePaths,
        supportedFileCount: Int,
        analyzedPhotoCount: Int,
        metadataRecordCount: Int,
        metadataCacheMaximumSizeMB: Int,
        metadataCacheHitCount: Int,
        generatedAt: Date = Date()
    ) -> AnalysisDiagnosticLog {
        AnalysisDiagnosticLog(
            generatedAt: ISO8601DateFormatter().string(from: generatedAt),
            datasetName: paths.packageURL.lastPathComponent,
            sourceFolderPath: sourceFolderURL.path,
            packageFolderPath: paths.packageURL.path,
            supportedFileCount: supportedFileCount,
            analyzedPhotoCount: analyzedPhotoCount,
            metadataRecordCount: metadataRecordCount,
            metadataCacheMaximumSizeMB: metadataCacheMaximumSizeMB,
            metadataCacheHitCount: metadataCacheHitCount,
            metadataCacheMissCount: max(0, analyzedPhotoCount - metadataCacheHitCount),
            outputFiles: [
                AIAnalysisPackagePaths.metadataFileName,
                AIAnalysisPackagePaths.statisticsFileName,
                AIAnalysisPackagePaths.qualityReportFileName,
                AIAnalysisPackagePaths.analysisLogFileName,
                AIAnalysisPackagePaths.contactSheetFileName,
                AIAnalysisPackagePaths.indexFileName,
                paths.archiveURL.lastPathComponent
            ]
        )
    }
}
