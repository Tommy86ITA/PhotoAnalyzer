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
            analyzeFiles: { fileURLs, progressHandler in
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
            exportDataFiles: { _, _, _, _, paths, progressHandler in
                progressHandler?(
                    ProgressSnapshot(
                        completedUnitCount: 2,
                        totalUnitCount: 2,
                        message: "Exporting statistics.json..."
                    )
                )
                return paths
            },
            exportContactSheet: { _, _, _, progressHandler in
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
