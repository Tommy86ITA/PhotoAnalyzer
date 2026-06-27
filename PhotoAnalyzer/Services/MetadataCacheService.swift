//
//  MetadataCacheService.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 27/06/2026.
//

import Foundation
import GRDB

nonisolated struct MetadataCacheUsage: Equatable, Sendable {
    let byteCount: Int64
    let entryCount: Int
}

/// SQLite-backed cache for raw ExifTool metadata JSON.
nonisolated final class MetadataCacheService: @unchecked Sendable {
    nonisolated private enum Table {
        static let metadataCache = "metadata_cache"
    }

    private struct CacheLookup: Sendable {
        let cacheKey: String
        let signature: MetadataCacheSignature
    }

    private struct MetadataCacheSignature: Equatable, Sendable {
        let sourceKind: String
        let sourceIdentifier: String
        let sourceVersion: String
        let filePath: String?
        let fileSize: Int64?
        let fileModificationTime: Double?
        let argumentsFingerprint: String
    }

    private static let schemaVersion = 1

    private let databaseQueue: DatabaseQueue?
    private let argumentsFingerprint: String

    init(
        databaseURL: URL? = nil,
        fileManager: FileManager = .default,
        analysisArguments: [String] = ExifToolTagWhitelist.analysisExportArguments
    ) {
        argumentsFingerprint = Self.fingerprint(for: analysisArguments)

        do {
            let url = databaseURL ?? Self.defaultDatabaseURL(fileManager: fileManager)
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let queue = try DatabaseQueue(path: url.path)
            try Self.migrate(queue)
            databaseQueue = queue
        } catch {
            #if DEBUG
            print("Metadata cache disabled: \(error.localizedDescription)")
            #endif
            databaseQueue = nil
        }
    }

    func cachedMetadataData(
        for fileURL: URL,
        sourceKey: MetadataCacheSourceKey?,
        maximumSizeBytes: Int64
    ) -> Data? {
        guard maximumSizeBytes > 0,
              let databaseQueue,
              let lookup = lookup(for: fileURL, sourceKey: sourceKey) else {
            return nil
        }

        do {
            return try databaseQueue.write { db in
                guard let row = try Row.fetchOne(
                    db,
                    sql: """
                    SELECT metadataData, sourceKind, sourceIdentifier, sourceVersion,
                           filePath, fileSize, fileModificationTime, argumentsFingerprint
                    FROM \(Table.metadataCache)
                    WHERE cacheKey = ?
                    """,
                    arguments: [lookup.cacheKey]
                ) else {
                    return nil
                }

                let signature = MetadataCacheSignature(
                    sourceKind: row["sourceKind"],
                    sourceIdentifier: row["sourceIdentifier"],
                    sourceVersion: row["sourceVersion"],
                    filePath: row["filePath"],
                    fileSize: row["fileSize"],
                    fileModificationTime: row["fileModificationTime"],
                    argumentsFingerprint: row["argumentsFingerprint"]
                )

                guard signature == lookup.signature else {
                    try db.execute(
                        sql: "DELETE FROM \(Table.metadataCache) WHERE cacheKey = ?",
                        arguments: [lookup.cacheKey]
                    )
                    return nil
                }

                try db.execute(
                    sql: "UPDATE \(Table.metadataCache) SET lastAccessedAt = ? WHERE cacheKey = ?",
                    arguments: [Date().timeIntervalSince1970, lookup.cacheKey]
                )
                return row["metadataData"] as Data
            }
        } catch {
            #if DEBUG
            print("Metadata cache read failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    func storeMetadataData(
        _ data: Data,
        for fileURL: URL,
        sourceKey: MetadataCacheSourceKey?,
        maximumSizeBytes: Int64
    ) {
        guard maximumSizeBytes > 0,
              let databaseQueue,
              let lookup = lookup(for: fileURL, sourceKey: sourceKey) else {
            return
        }

        do {
            try databaseQueue.write { db in
                let now = Date().timeIntervalSince1970
                try db.execute(
                    sql: """
                    INSERT INTO \(Table.metadataCache) (
                        cacheKey, sourceKind, sourceIdentifier, sourceVersion,
                        filePath, fileSize, fileModificationTime, argumentsFingerprint,
                        metadataData, metadataByteCount, createdAt, lastAccessedAt
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(cacheKey) DO UPDATE SET
                        sourceKind = excluded.sourceKind,
                        sourceIdentifier = excluded.sourceIdentifier,
                        sourceVersion = excluded.sourceVersion,
                        filePath = excluded.filePath,
                        fileSize = excluded.fileSize,
                        fileModificationTime = excluded.fileModificationTime,
                        argumentsFingerprint = excluded.argumentsFingerprint,
                        metadataData = excluded.metadataData,
                        metadataByteCount = excluded.metadataByteCount,
                        lastAccessedAt = excluded.lastAccessedAt
                    """,
                    arguments: [
                        lookup.cacheKey,
                        lookup.signature.sourceKind,
                        lookup.signature.sourceIdentifier,
                        lookup.signature.sourceVersion,
                        lookup.signature.filePath,
                        lookup.signature.fileSize,
                        lookup.signature.fileModificationTime,
                        lookup.signature.argumentsFingerprint,
                        data,
                        data.count,
                        now,
                        now
                    ]
                )
                try Self.enforceLimit(maximumSizeBytes, in: db)
            }
        } catch {
            #if DEBUG
            print("Metadata cache write failed: \(error.localizedDescription)")
            #endif
        }
    }

    func usage() -> MetadataCacheUsage {
        guard let databaseQueue else {
            return MetadataCacheUsage(byteCount: 0, entryCount: 0)
        }

        do {
            return try databaseQueue.read { db in
                let row = try Row.fetchOne(
                    db,
                    sql: """
                    SELECT COALESCE(SUM(metadataByteCount), 0) AS byteCount,
                           COUNT(*) AS entryCount
                    FROM \(Table.metadataCache)
                    """
                )

                return MetadataCacheUsage(
                    byteCount: row?["byteCount"] ?? 0,
                    entryCount: row?["entryCount"] ?? 0
                )
            }
        } catch {
            return MetadataCacheUsage(byteCount: 0, entryCount: 0)
        }
    }

    func removeAll() {
        guard let databaseQueue else {
            return
        }

        do {
            try databaseQueue.write { db in
                try db.execute(sql: "DELETE FROM \(Table.metadataCache)")
            }
        } catch {
            #if DEBUG
            print("Metadata cache clear failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func lookup(for fileURL: URL, sourceKey: MetadataCacheSourceKey?) -> CacheLookup? {
        if let sourceKey {
            let signature = MetadataCacheSignature(
                sourceKind: sourceKey.kind.rawValue,
                sourceIdentifier: sourceKey.identifier,
                sourceVersion: sourceKey.version,
                filePath: nil,
                fileSize: nil,
                fileModificationTime: nil,
                argumentsFingerprint: argumentsFingerprint
            )
            return CacheLookup(
                cacheKey: Self.fingerprint(for: [
                    signature.sourceKind,
                    signature.sourceIdentifier,
                    signature.argumentsFingerprint
                ]),
                signature: signature
            )
        }

        guard let values = try? fileURL.resourceValues(forKeys: [
            .contentModificationDateKey,
            .fileSizeKey,
            .isRegularFileKey
        ]),
              values.isRegularFile == true,
              let fileSize = values.fileSize else {
            return nil
        }

        let path = fileURL.standardizedFileURL.path
        let modificationTime = values.contentModificationDate?.timeIntervalSince1970
        let signature = MetadataCacheSignature(
            sourceKind: MetadataCacheSourceKey.SourceKind.localFile.rawValue,
            sourceIdentifier: path,
            sourceVersion: "file",
            filePath: path,
            fileSize: Int64(fileSize),
            fileModificationTime: modificationTime,
            argumentsFingerprint: argumentsFingerprint
        )

        return CacheLookup(
            cacheKey: Self.fingerprint(for: [
                signature.sourceKind,
                signature.sourceIdentifier,
                signature.argumentsFingerprint
            ]),
            signature: signature
        )
    }

    private static func migrate(_ databaseQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createMetadataCache") { db in
            try db.create(table: Table.metadataCache, ifNotExists: true) { table in
                table.column("cacheKey", .text).primaryKey()
                table.column("sourceKind", .text).notNull()
                table.column("sourceIdentifier", .text).notNull()
                table.column("sourceVersion", .text).notNull()
                table.column("filePath", .text)
                table.column("fileSize", .integer)
                table.column("fileModificationTime", .double)
                table.column("argumentsFingerprint", .text).notNull()
                table.column("metadataData", .blob).notNull()
                table.column("metadataByteCount", .integer).notNull()
                table.column("createdAt", .double).notNull()
                table.column("lastAccessedAt", .double).notNull()
            }
            try db.create(index: "metadata_cache_last_accessed", on: Table.metadataCache, columns: ["lastAccessedAt"])
        }
        try migrator.migrate(databaseQueue)
    }

    private static func enforceLimit(_ maximumSizeBytes: Int64, in db: Database) throws {
        var totalSize: Int64 = try Int64.fetchOne(
            db,
            sql: "SELECT COALESCE(SUM(metadataByteCount), 0) FROM \(Table.metadataCache)"
        ) ?? 0

        while totalSize > maximumSizeBytes {
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT cacheKey, metadataByteCount
                FROM \(Table.metadataCache)
                ORDER BY lastAccessedAt ASC
                LIMIT 1
                """
            ) else {
                return
            }

            let cacheKey: String = row["cacheKey"]
            let byteCount: Int64 = row["metadataByteCount"]
            try db.execute(
                sql: "DELETE FROM \(Table.metadataCache) WHERE cacheKey = ?",
                arguments: [cacheKey]
            )
            totalSize -= byteCount
        }
    }

    private static func defaultDatabaseURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        return baseURL
            .appendingPathComponent("PhotoAnalyzer", isDirectory: true)
            .appendingPathComponent("MetadataCache.sqlite")
    }

    private static func fingerprint(for values: [String]) -> String {
        let joinedValue = values.joined(separator: "\u{1F}")
        let hash = joinedValue.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { result, byte in
            (result ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
