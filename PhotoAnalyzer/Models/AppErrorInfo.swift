//
//  AppErrorInfo.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Foundation

/// Structured error information suitable for UI display and diagnostics.
nonisolated struct AppErrorInfo: Equatable, Sendable {
    let userMessage: String
    let debugDescription: String

    static func exportFailure(_ error: Error) -> AppErrorInfo {
        let localizedMessage = error.localizedDescription
        let reflectedError = String(reflecting: error)

        return AppErrorInfo(
            userMessage: "Export failed: \(localizedMessage)",
            debugDescription: reflectedError == localizedMessage
                ? localizedMessage
                : "\(localizedMessage) (\(reflectedError))"
        )
    }

    static func photosSkippedAssets(_ failures: [PhotosAssetExportFailure]) -> AppErrorInfo? {
        guard !failures.isEmpty else {
            return nil
        }

        let pluralizedAsset = failures.count == 1 ? "asset" : "assets"
        let userMessage = "\(failures.count) Photos \(pluralizedAsset) skipped. Some originals may be unavailable locally."
        let debugDescription = failures
            .map { "\($0.assetLocalIdentifier): \($0.reason)" }
            .joined(separator: "\n")

        return AppErrorInfo(
            userMessage: userMessage,
            debugDescription: debugDescription
        )
    }
}
