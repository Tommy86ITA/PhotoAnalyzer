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
}
