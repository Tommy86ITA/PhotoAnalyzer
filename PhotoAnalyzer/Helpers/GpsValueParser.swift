//
//  GpsValueParser.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation

/// A helper for converting human-readable ExifTool GPS values into numeric values.
enum GpsValueParser {
    /// Parses a coordinate string in degrees, minutes, seconds format.
    /// - Parameter value: A coordinate such as `39 deg 18' 20.01" N`.
    /// - Returns: Decimal degrees, or `nil` when parsing fails.
    nonisolated static func parseCoordinate(_ value: String?) -> Double? {
        guard let value else {
            return nil
        }

        let pattern = #"^\s*([+-]?\d+(?:\.\d+)?)\s*deg\s+(\d+(?:\.\d+)?)'\s+(\d+(?:\.\d+)?)"\s*([NSEW])\s*$"#
        guard let match = firstMatch(pattern: pattern, in: value) else {
            return nil
        }

        guard let degrees = double(from: value, range: match.range(at: 1)),
              let minutes = double(from: value, range: match.range(at: 2)),
              let seconds = double(from: value, range: match.range(at: 3)),
              let direction = string(from: value, range: match.range(at: 4)) else {
            return nil
        }

        let sign = direction == "S" || direction == "W" ? -1.0 : 1.0
        return sign * (degrees + minutes / 60.0 + seconds / 3600.0)
    }

    /// Parses an altitude string with sea-level direction.
    /// - Parameter value: An altitude such as `138.4 m Above Sea Level`.
    /// - Returns: Altitude in meters, or `nil` when parsing fails.
    nonisolated static func parseAltitude(_ value: String?) -> Double? {
        guard let value else {
            return nil
        }

        let pattern = #"^\s*([+-]?\d+(?:\.\d+)?)\s*m(?:\s+(Above|Below)\s+Sea\s+Level)?\s*$"#
        guard let match = firstMatch(pattern: pattern, in: value),
              let altitude = double(from: value, range: match.range(at: 1)) else {
            return nil
        }

        let seaLevelDirection = string(from: value, range: match.range(at: 2))
        return seaLevelDirection == "Below" ? -altitude : altitude
    }

    /// Finds the first regular expression match in a string.
    /// - Parameters:
    ///   - pattern: The regular expression pattern.
    ///   - value: The string to inspect.
    /// - Returns: The first match, or `nil` when no match is found.
    nonisolated private static func firstMatch(pattern: String, in value: String) -> NSTextCheckingResult? {
        guard let regularExpression = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regularExpression.firstMatch(in: value, range: range)
    }

    /// Extracts a `Double` from a regular expression capture range.
    /// - Parameters:
    ///   - value: The source string.
    ///   - range: The capture range.
    /// - Returns: The parsed double value, or `nil` when unavailable.
    nonisolated private static func double(from value: String, range: NSRange) -> Double? {
        guard let string = string(from: value, range: range) else {
            return nil
        }

        return Double(string)
    }

    /// Extracts a `String` from a regular expression capture range.
    /// - Parameters:
    ///   - value: The source string.
    ///   - range: The capture range.
    /// - Returns: The captured string, or `nil` when unavailable.
    nonisolated private static func string(from value: String, range: NSRange) -> String? {
        guard range.location != NSNotFound,
              let swiftRange = Range(range, in: value) else {
            return nil
        }

        return String(value[swiftRange])
    }
}
