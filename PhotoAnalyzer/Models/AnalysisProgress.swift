//
//  AnalysisProgress.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import Foundation

/// Service-level progress emitted by long-running pipeline steps.
nonisolated struct ProgressSnapshot: Sendable {
    let completedUnitCount: Int64
    let totalUnitCount: Int64
    let message: String

    var fractionCompleted: Double {
        guard totalUnitCount > 0 else {
            return 0
        }

        return min(1, max(0, Double(completedUnitCount) / Double(totalUnitCount)))
    }
}

/// UI-level progress for the complete analysis pipeline.
nonisolated struct AnalysisProgress: Sendable {
    let fractionCompleted: Double
    let message: String

    init(fractionCompleted: Double, message: String) {
        self.fractionCompleted = min(1, max(0, fractionCompleted))
        self.message = message
    }
}

/// Maps service-level progress into a global pipeline progress value.
nonisolated struct PipelineProgressMapper: Sendable {
    let startingUnitCount: Int64
    let totalUnitCount: Int64
    let allocatedUnitCount: Int64?

    init(startingUnitCount: Int64, totalUnitCount: Int64, allocatedUnitCount: Int64? = nil) {
        self.startingUnitCount = startingUnitCount
        self.totalUnitCount = totalUnitCount
        self.allocatedUnitCount = allocatedUnitCount
    }

    func map(_ snapshot: ProgressSnapshot) -> AnalysisProgress {
        let completedUnitCount: Double
        if let allocatedUnitCount {
            completedUnitCount = Double(startingUnitCount) + snapshot.fractionCompleted * Double(allocatedUnitCount)
        } else {
            completedUnitCount = Double(startingUnitCount + snapshot.completedUnitCount)
        }

        return AnalysisProgress(
            fractionCompleted: fraction(from: completedUnitCount),
            message: snapshot.message
        )
    }

    func map(completedUnitCount: Int64, message: String) -> AnalysisProgress {
        AnalysisProgress(
            fractionCompleted: fraction(from: Double(completedUnitCount)),
            message: message
        )
    }

    private func fraction(from completedUnitCount: Double) -> Double {
        guard totalUnitCount > 0 else {
            return 0
        }

        return min(1, max(0, completedUnitCount / Double(totalUnitCount)))
    }
}
