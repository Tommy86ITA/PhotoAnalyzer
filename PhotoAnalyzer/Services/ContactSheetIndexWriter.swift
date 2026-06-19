//
//  ContactSheetIndexWriter.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import Foundation

nonisolated struct ContactSheetIndexWriter {
    nonisolated func write(_ rows: [ContactSheetIndexRow], to url: URL) throws {
        var lines = ["Index\tSheet\tFileName\tSourceFile\tRow\tColumn\tError"]
        lines += rows.map { row in
            [
                row.index,
                escapedTSVValue(row.sheet),
                escapedTSVValue(row.fileName),
                escapedTSVValue(row.sourceFile),
                String(row.row),
                String(row.column),
                escapedTSVValue(row.error ?? "")
            ].joined(separator: "\t")
        }

        try lines.joined(separator: "\n")
            .appending("\n")
            .write(to: url, atomically: true, encoding: .utf8)
    }

    nonisolated private func escapedTSVValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
