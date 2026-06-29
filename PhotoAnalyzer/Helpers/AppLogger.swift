//
//  AppLogger.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 29/06/2026.
//

import Foundation
import OSLog

/// Centralized OSLog loggers for PhotoAnalyzer subsystems.
enum AppLogger {
    private nonisolated static let subsystem = Bundle.main.bundleIdentifier ?? "PhotoAnalyzer"

    nonisolated static let analysis = Logger(subsystem: subsystem, category: "analysis")
    nonisolated static let cache = Logger(subsystem: subsystem, category: "cache")
    nonisolated static let contactSheet = Logger(subsystem: subsystem, category: "contact-sheet")
    nonisolated static let export = Logger(subsystem: subsystem, category: "export")
    nonisolated static let performance = Logger(subsystem: subsystem, category: "performance")
    nonisolated static let security = Logger(subsystem: subsystem, category: "security")
}
