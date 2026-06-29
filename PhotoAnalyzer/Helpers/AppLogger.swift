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
    private static let subsystem = Bundle.main.bundleIdentifier ?? "PhotoAnalyzer"

    nonisolated(unsafe) static let analysis = Logger(subsystem: subsystem, category: "analysis")
    nonisolated(unsafe) static let cache = Logger(subsystem: subsystem, category: "cache")
    nonisolated(unsafe) static let contactSheet = Logger(subsystem: subsystem, category: "contact-sheet")
    nonisolated(unsafe) static let export = Logger(subsystem: subsystem, category: "export")
    nonisolated(unsafe) static let performance = Logger(subsystem: subsystem, category: "performance")
    nonisolated(unsafe) static let security = Logger(subsystem: subsystem, category: "security")
}
