//
//  ExifToolValueParser.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation

/// Shared parsing helpers for ExifTool values that may include units or formatted text.
nonisolated enum ExifToolValueParser {
    /// Extracts the first numeric value from a string such as `6.8 mm` or `106 mm`.
    /// - Parameter value: The ExifTool value to inspect.
    /// - Returns: The first numeric value, or `nil` when unavailable.
    static func double(from value: String?) -> Double? {
        guard let value else {
            return nil
        }

        let pattern = #"[-+]?\d+(?:\.\d+)?"#
        guard let range = value.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        return Double(value[range])
    }

    /// Extracts the first integer value from a string.
    /// - Parameter value: The ExifTool value to inspect.
    /// - Returns: The first integer value, or `nil` when unavailable.
    static func int(from value: String?) -> Int? {
        double(from: value).map { Int($0) }
    }

    /// Parses a simple exposure time value.
    /// - Parameter value: The ExifTool exposure time value.
    /// - Returns: Exposure time in seconds, or `nil` when parsing is unavailable.
    static func exposureTime(from value: String?) -> Double? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmedValue.split(separator: "/")

        if parts.count == 2,
           let numerator = Double(parts[0]),
           let denominator = Double(parts[1]),
           denominator != 0 {
            return numerator / denominator
        }

        return double(from: trimmedValue)
    }

    /// Parses a GPS coordinate using the local GPS parser and decimal fallback.
    /// - Parameter value: The ExifTool GPS coordinate value.
    /// - Returns: A decimal GPS coordinate, or `nil` when unavailable.
    static func gpsCoordinate(from value: String?) -> Double? {
        guard let value else {
            return nil
        }

        return GpsValueParser.parseCoordinate(value) ?? Double(value)
    }

    /// Parses a GPS altitude using the local GPS parser and decimal fallback.
    /// - Parameter value: The ExifTool GPS altitude value.
    /// - Returns: A GPS altitude, or `nil` when unavailable.
    static func gpsAltitude(from value: String?) -> Double? {
        guard let value else {
            return nil
        }

        return GpsValueParser.parseAltitude(value) ?? Double(value)
    }
}
