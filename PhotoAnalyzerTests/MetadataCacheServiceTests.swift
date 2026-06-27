//
//  MetadataCacheServiceTests.swift
//  PhotoAnalyzerTests
//
//  Created by Thomas Amaranto on 27/06/2026.
//

import Foundation
import Testing
@testable import PhotoAnalyzer

struct MetadataCacheServiceTests {
    @Test func storesAndReadsMetadataForUnchangedFile() throws {
        let fixture = try makeFixture()
        defer {
            try? FileManager.default.removeItem(at: fixture.directoryURL)
        }

        let service = MetadataCacheService(databaseURL: fixture.databaseURL)
        let payload = Data(#"[{"SourceFile":"/tmp/photo.jpg","File:FileName":"photo.jpg"}]"#.utf8)

        service.storeMetadataData(
            payload,
            for: fixture.fileURL,
            sourceKey: nil,
            maximumSizeBytes: 1_000_000
        )

        #expect(service.cachedMetadataData(
            for: fixture.fileURL,
            sourceKey: nil,
            maximumSizeBytes: 1_000_000
        ) == payload)
        #expect(service.usage().entryCount == 1)
    }

    @Test func invalidatesLocalFileEntryWhenFileChanges() throws {
        let fixture = try makeFixture()
        defer {
            try? FileManager.default.removeItem(at: fixture.directoryURL)
        }

        let service = MetadataCacheService(databaseURL: fixture.databaseURL)
        let payload = Data(#"[{"SourceFile":"/tmp/photo.jpg","File:FileName":"photo.jpg"}]"#.utf8)

        service.storeMetadataData(
            payload,
            for: fixture.fileURL,
            sourceKey: nil,
            maximumSizeBytes: 1_000_000
        )

        try Data("changed".utf8).write(to: fixture.fileURL)

        #expect(service.cachedMetadataData(
            for: fixture.fileURL,
            sourceKey: nil,
            maximumSizeBytes: 1_000_000
        ) == nil)
        #expect(service.usage().entryCount == 0)
    }

    private func makeFixture() throws -> CacheFixture {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent("photo.jpg")
        try Data("original".utf8).write(to: fileURL)

        return CacheFixture(
            directoryURL: directoryURL,
            databaseURL: directoryURL.appendingPathComponent("cache.sqlite"),
            fileURL: fileURL
        )
    }
}

private struct CacheFixture {
    let directoryURL: URL
    let databaseURL: URL
    let fileURL: URL
}
