//
//  AnalysisPipelineServiceTests.swift
//  PhotoAnalyzerTests
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Foundation
import Testing
@testable import PhotoAnalyzer

struct AnalysisPipelineServiceTests {
    @Test func runUsesInjectedDependenciesAndEmitsStructuredProgress() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let fileURL = directoryURL.appendingPathComponent("one.jpg")
        let photo = PhotoInfo(
            fileName: "one.jpg",
            captureDate: nil,
            cameraMake: nil,
            cameraModel: "Camera",
            lensModel: nil,
            focalLength: 50,
            focalLength35mmEquivalent: 50,
            iso: 100,
            aperture: 2,
            exposureTime: 1.0 / 60.0,
            latitude: nil,
            longitude: nil,
            photoType: .standard
        )
        let statistics = PhotoStatistics(
            totalPhotos: 1,
            photosByType: [.standard: 1],
            photosByCamera: ["Camera": 1],
            isoDistribution: [100: 1],
            focalLength35mmDistribution: [50: 1],
            apertureDistribution: ["f/2": 1],
            shutterSpeedDistribution: ["1/60": 1],
            lensDistribution: ["Unknown": 1],
            averageISO: 100,
            averageFocalLength35mmEquivalent: 50
        )
        let progressRecorder = LockedArray<AnalysisPhase>()
        let dependencies = AnalysisPipelineDependencies(
            scanImageFiles: { _, _, _, progressHandler in
                progressHandler?(
                    ProgressSnapshot(
                        completedUnitCount: 1,
                        totalUnitCount: 1,
                        message: "Scanning files..."
                    )
                )
                return [fileURL]
            },
            analyzeFiles: { fileURLs, _, _, progressHandler in
                progressHandler?(
                    ProgressSnapshot(
                        completedUnitCount: 1,
                        totalUnitCount: 1,
                        message: "Reading metadata..."
                    )
                )
                return FolderAnalysisResult(photos: [photo], exportMetadata: [], fileURLs: fileURLs)
            },
            buildStatistics: { _ in
                statistics
            },
            exportDataFiles: { _, _, _, _, paths, _, progressHandler in
                progressHandler?(
                    ProgressSnapshot(
                        completedUnitCount: 2,
                        totalUnitCount: 2,
                        message: "Exporting statistics.json..."
                    )
                )
                return paths
            },
            exportContactSheet: { _, _, _, _, progressHandler in
                progressHandler?(
                    ProgressSnapshot(
                        completedUnitCount: 1,
                        totalUnitCount: 1,
                        message: "Writing contact sheet..."
                    )
                )
            },
            archivePackage: { paths, progressHandler in
                progressHandler?(
                    ProgressSnapshot(
                        completedUnitCount: 1,
                        totalUnitCount: 1,
                        message: "Archiving package..."
                    )
                )
                return paths.archiveURL
            }
        )

        let result = try await AnalysisPipelineService(dependencies: dependencies).run(
            request: AnalysisPipelineRequest(
                folderURL: directoryURL,
                outputFolderURL: nil,
                includeSubfolders: false,
                expectedSupportedFileCount: 1
            ),
            progressHandler: { progress in
                if let phase = progress.phase {
                    progressRecorder.append(phase)
                }
            }
        )

        #expect(result.supportedFileCount == 1)
        #expect(result.analyzedPhotoCount == 1)
        #expect(result.statistics.totalPhotos == 1)
        #expect(progressRecorder.values.contains(.scanningFiles))
        #expect(progressRecorder.values.contains(.readingMetadata))
        #expect(progressRecorder.values.contains(.exportingAIPackage))
        #expect(progressRecorder.values.contains(.generatingContactSheet))
        #expect(progressRecorder.values.contains(.archivingPackage))
        #expect(progressRecorder.values.last == .completed)
    }

    @Test func runPreparedFilesExportsOptionalDiagnosticReports() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let fileURL = directoryURL.appendingPathComponent("diagnostic.jpg")
        let photo = PhotoInfo(
            fileName: "diagnostic.jpg",
            captureDate: nil,
            cameraMake: nil,
            cameraModel: nil,
            lensModel: nil,
            focalLength: nil,
            focalLength35mmEquivalent: nil,
            iso: nil,
            aperture: nil,
            exposureTime: nil,
            latitude: nil,
            longitude: nil,
            photoType: .standard
        )
        let statistics = PhotoStatistics(
            totalPhotos: 1,
            photosByType: [.standard: 1],
            photosByCamera: [:],
            isoDistribution: [:],
            focalLength35mmDistribution: [:],
            apertureDistribution: [:],
            shutterSpeedDistribution: [:],
            lensDistribution: [:],
            averageISO: nil,
            averageFocalLength35mmEquivalent: nil
        )
        let dependencies = AnalysisPipelineDependencies(
            scanImageFiles: { _, _, _, _ in [] },
            analyzeFiles: { fileURLs, _, _, _ in
                FolderAnalysisResult(
                    photos: [photo],
                    exportMetadata: [],
                    fileURLs: fileURLs,
                    metadataCacheHitCount: 1
                )
            },
            buildStatistics: { _ in statistics },
            exportDataFiles: { _, _, _, _, paths, _, _ in
                try FileManager.default.createDirectory(at: paths.packageURL, withIntermediateDirectories: true)
                return paths
            },
            exportContactSheet: { _, _, _, _, _ in },
            archivePackage: { paths, _ in
                #expect(!FileManager.default.fileExists(atPath: paths.qualityReportURL.path))
                #expect(!FileManager.default.fileExists(atPath: paths.analysisLogURL.path))
                return paths.archiveURL
            }
        )

        let result = try await AnalysisPipelineService(dependencies: dependencies).runPreparedFiles(
            request: PreparedAnalysisPipelineRequest(
                sourceFolderURL: directoryURL,
                outputFolderURL: nil,
                fileURLs: [fileURL],
                metadataCacheMaximumSizeMB: 512,
                exportDiagnosticReports: true
            ),
            progressHandler: nil
        )

        #expect(FileManager.default.fileExists(atPath: result.paths.qualityReportURL.path))
        #expect(FileManager.default.fileExists(atPath: result.paths.analysisLogURL.path))
    }

    @Test func runPreparedFilesBypassesFolderScanning() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let fileURL = directoryURL.appendingPathComponent("prepared.jpg")
        let photo = PhotoInfo(
            fileName: "prepared.jpg",
            captureDate: nil,
            cameraMake: nil,
            cameraModel: nil,
            lensModel: nil,
            focalLength: nil,
            focalLength35mmEquivalent: nil,
            iso: nil,
            aperture: nil,
            exposureTime: nil,
            latitude: nil,
            longitude: nil,
            photoType: .standard
        )
        let statistics = PhotoStatistics(
            totalPhotos: 1,
            photosByType: [.standard: 1],
            photosByCamera: [:],
            isoDistribution: [:],
            focalLength35mmDistribution: [:],
            apertureDistribution: [:],
            shutterSpeedDistribution: [:],
            lensDistribution: [:],
            averageISO: nil,
            averageFocalLength35mmEquivalent: nil
        )
        let scannedFolders = LockedArray<URL>()
        let progressRecorder = LockedArray<AnalysisPhase>()
        let dependencies = AnalysisPipelineDependencies(
            scanImageFiles: { folderURL, _, _, _ in
                scannedFolders.append(folderURL)
                return []
            },
            analyzeFiles: { fileURLs, _, _, progressHandler in
                progressHandler?(
                    ProgressSnapshot(
                        completedUnitCount: 1,
                        totalUnitCount: 1,
                        message: "Reading metadata..."
                    )
                )
                return FolderAnalysisResult(photos: [photo], exportMetadata: [], fileURLs: fileURLs)
            },
            buildStatistics: { _ in
                statistics
            },
            exportDataFiles: { _, _, _, _, paths, _, progressHandler in
                progressHandler?(
                    ProgressSnapshot(
                        completedUnitCount: 2,
                        totalUnitCount: 2,
                        message: "Exporting statistics.json..."
                    )
                )
                return paths
            },
            exportContactSheet: { _, _, _, _, progressHandler in
                progressHandler?(
                    ProgressSnapshot(
                        completedUnitCount: 1,
                        totalUnitCount: 1,
                        message: "Writing contact sheet..."
                    )
                )
            },
            archivePackage: { paths, progressHandler in
                progressHandler?(
                    ProgressSnapshot(
                        completedUnitCount: 1,
                        totalUnitCount: 1,
                        message: "Archiving package..."
                    )
                )
                return paths.archiveURL
            }
        )

        let result = try await AnalysisPipelineService(dependencies: dependencies).runPreparedFiles(
            request: PreparedAnalysisPipelineRequest(
                sourceFolderURL: directoryURL,
                outputFolderURL: nil,
                fileURLs: [fileURL]
            ),
            progressHandler: { progress in
                if let phase = progress.phase {
                    progressRecorder.append(phase)
                }
            }
        )

        #expect(scannedFolders.values.isEmpty)
        #expect(result.supportedFileCount == 1)
        #expect(result.analyzedPhotoCount == 1)
        #expect(!progressRecorder.values.contains(.scanningFiles))
        #expect(progressRecorder.values.contains(.readingMetadata))
        #expect(progressRecorder.values.last == .completed)
    }

    @Test func runPreparedFilesPassesDisplayInfoToExporters() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let fileURL = directoryURL.appendingPathComponent("materialized.jpg")
        let displayInfo = SourceFileDisplayInfo(
            fileName: "IMG_0001.HEIC",
            sourceFile: "photos://asset/local-id-1"
        )
        let photo = PhotoInfo(
            fileName: "materialized.jpg",
            captureDate: nil,
            cameraMake: nil,
            cameraModel: nil,
            lensModel: nil,
            focalLength: nil,
            focalLength35mmEquivalent: nil,
            iso: nil,
            aperture: nil,
            exposureTime: nil,
            latitude: nil,
            longitude: nil,
            photoType: .standard
        )
        let statistics = PhotoStatistics(
            totalPhotos: 1,
            photosByType: [.standard: 1],
            photosByCamera: [:],
            isoDistribution: [:],
            focalLength35mmDistribution: [:],
            apertureDistribution: [:],
            shutterSpeedDistribution: [:],
            lensDistribution: [:],
            averageISO: nil,
            averageFocalLength35mmEquivalent: nil
        )
        let exportedDisplayInfo = LockedArray<SourceFileDisplayInfo>()
        let contactSheetDisplayInfo = LockedArray<SourceFileDisplayInfo>()
        let dependencies = AnalysisPipelineDependencies(
            scanImageFiles: { _, _, _, _ in [] },
            analyzeFiles: { fileURLs, _, _, _ in
                FolderAnalysisResult(photos: [photo], exportMetadata: [], fileURLs: fileURLs)
            },
            buildStatistics: { _ in statistics },
            exportDataFiles: { _, _, _, _, paths, displayInfoByFileURL, _ in
                if let displayInfo = displayInfoByFileURL[fileURL] {
                    exportedDisplayInfo.append(displayInfo)
                }
                return paths
            },
            exportContactSheet: { _, _, _, displayInfoByFileURL, _ in
                if let displayInfo = displayInfoByFileURL[fileURL] {
                    contactSheetDisplayInfo.append(displayInfo)
                }
            },
            archivePackage: { paths, _ in paths.archiveURL }
        )

        _ = try await AnalysisPipelineService(dependencies: dependencies).runPreparedFiles(
            request: PreparedAnalysisPipelineRequest(
                sourceFolderURL: directoryURL,
                outputFolderURL: nil,
                fileURLs: [fileURL],
                displayInfoByFileURL: [fileURL: displayInfo]
            ),
            progressHandler: nil
        )

        #expect(exportedDisplayInfo.values == [displayInfo])
        #expect(contactSheetDisplayInfo.values == [displayInfo])
    }
}

private final class LockedArray<Element>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Element] = []

    var values: [Element] {
        lock.lock()
        defer {
            lock.unlock()
        }
        return storage
    }

    func append(_ element: Element) {
        lock.lock()
        storage.append(element)
        lock.unlock()
    }
}
