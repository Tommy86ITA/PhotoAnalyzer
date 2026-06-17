//
//  JSONFileWriter.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation

/// Writes stable, readable JSON files for export artifacts.
final class JSONFileWriter {
    /// Creates a JSON file writer.
    nonisolated init() {}

    /// Encodes and writes a value to disk using the package JSON format.
    /// - Parameters:
    ///   - value: The encodable value to write.
    ///   - url: The destination file URL.
    /// - Throws: JSON encoding or file system errors.
    nonisolated func write<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }

    private nonisolated var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
