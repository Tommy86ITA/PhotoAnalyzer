//
//  ContactSheetIndexWriterTests.swift
//  PhotoAnalyzerTests
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Foundation
import Testing
@testable import PhotoAnalyzer

struct ContactSheetIndexWriterTests {
    @Test func writeEscapesTabAndNewlineSeparatedValues() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let indexURL = directoryURL.appendingPathComponent("index.tsv")
        let rows = [
            ContactSheetIndexRow(
                index: "001",
                sheet: "contact_sheet_001.jpg",
                fileName: "one\tfile.jpg",
                sourceFile: "/tmp/one\nfile.jpg",
                row: 1,
                column: 2,
                error: "warning\rmessage"
            )
        ]

        try ContactSheetIndexWriter().write(rows, to: indexURL)

        let contents = try String(contentsOf: indexURL, encoding: .utf8)
        #expect(contents == """
        Index\tSheet\tFileName\tSourceFile\tRow\tColumn\tError
        001\tcontact_sheet_001.jpg\tone file.jpg\t/tmp/one file.jpg\t1\t2\twarning message

        """)
    }
}
