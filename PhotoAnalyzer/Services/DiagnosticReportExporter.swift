//
//  DiagnosticReportExporter.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 28/06/2026.
//

import Foundation

/// Writes optional diagnostic artifacts into an AI analysis package.
nonisolated struct DiagnosticReportExporter {
    func export(
        qualityReport: DatasetQualityReport,
        diagnosticLog: AnalysisDiagnosticLog,
        paths: AIAnalysisPackagePaths
    ) throws {
        let writer = JSONFileWriter()
        try writer.write(qualityReport, to: paths.qualityReportURL)
        try writer.write(diagnosticLog, to: paths.analysisLogURL)
    }
}
