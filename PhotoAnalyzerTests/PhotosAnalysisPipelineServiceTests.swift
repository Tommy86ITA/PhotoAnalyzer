//
//  PhotosAnalysisPipelineServiceTests.swift
//  PhotoAnalyzerTests
//
//  Created by Thomas Amaranto on 20/06/2026.
//

import Foundation
import Testing
@testable import PhotoAnalyzer

struct PhotosAnalysisPipelineServiceTests {
    @Test func runMaterializesPhotosSelectionAndRunsPreparedPipeline() async throws {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let photo = PhotoInfo(
            fileName: "materialized.heic",
            captureDate: nil,
            cameraMake: "Apple",
            cameraModel: "iPhone",
            lensModel: nil,
            focalLength: 24,
            focalLength35mmEquivalent: 24,
            iso: 100,
            aperture: 1.8,
            exposureTime: 1.0 / 120.0,
            latitude: nil,
            longitude: nil,
            photoType: .standard
        )
        let statistics = PhotoStatistics(
            totalPhotos: 1,
            photosByType: [.standard: 1],
            photosByCamera: ["Apple iPhone": 1],
            isoDistribution: [100: 1],
            focalLength35mmDistribution: [24: 1],
            apertureDistribution: ["f/1.8": 1],
            shutterSpeedDistribution: ["1/120": 1],
            lensDistribution: [:],
            averageISO: 100,
            averageFocalLength35mmEquivalent: 24
        )
        let materializedSelections = LockedArray<PhotosSelection>()
        let materializationProgress = LockedArray<ProgressSnapshot>()
        let exportedDisplayInfo = LockedArray<SourceFileDisplayInfo>()
        let dependencies = AnalysisPipelineDependencies(
            scanImageFiles: { _, _, _, _ in [] },
            analyzeFiles: { fileURLs, _ in
                FolderAnalysisResult(photos: [photo], exportMetadata: [], fileURLs: fileURLs)
            },
            buildStatistics: { _ in statistics },
            exportDataFiles: { _, _, sourceFileURLs, _, paths, displayInfoByFileURL, _ in
                if let fileURL = sourceFileURLs.first,
                   let displayInfo = displayInfoByFileURL[fileURL] {
                    exportedDisplayInfo.append(displayInfo)
                }
                return paths
            },
            exportContactSheet: { _, _, _, _, _ in },
            archivePackage: { paths, _ in paths.archiveURL }
        )
        let pipelineService = AnalysisPipelineService(dependencies: dependencies)
        let service = PhotosAnalysisPipelineService(
            materializeSelection: { selection, _, progressHandler in
                materializedSelections.append(selection)
                let snapshot = ProgressSnapshot(
                    completedUnitCount: 1,
                    totalUnitCount: 1,
                    message: "Preparing Photos assets..."
                )
                materializationProgress.append(snapshot)
                progressHandler?(snapshot)
                let workspace = try TemporaryAssetWorkspace(rootDirectoryURL: outputURL)
                let fileURL = workspace.fileURL(
                    preferredFilename: "materialized.heic",
                    fallbackBasename: "materialized"
                )
                _ = FileManager.default.createFile(atPath: fileURL.path, contents: Data())
                let asset = MaterializedPhotosAsset(
                    assetLocalIdentifier: "asset/1",
                    originalFilename: "IMG_0001.HEIC",
                    fileURL: fileURL,
                    representation: selection.representation
                )
                let skipped = PhotosAssetExportFailure(
                    assetLocalIdentifier: "asset/2",
                    reason: "iCloud original unavailable"
                )
                return PhotosMaterializationResult(
                    assets: [asset],
                    skippedAssets: [skipped],
                    workspace: workspace
                )
            },
            pipelineService: pipelineService
        )
        let selection = PhotosSelection(
            mode: .album(localIdentifier: "album-1", name: "Favorites"),
            representation: .current,
            networkAccessPolicy: .downloadMissingOriginals
        )
        let phases = LockedArray<AnalysisPhase>()

        let result = try await service.run(
            request: PhotosAnalysisPipelineRequest(
                selection: selection,
                outputFolderURL: nil,
                datasetName: "Favorites",
                exportOptions: PhotosLibraryExportOptions(maximumAssetCount: 100)
            ),
            progressHandler: { progress in
                if let phase = progress.phase {
                    phases.append(phase)
                }
            }
        )

        #expect(materializedSelections.values == [selection])
        #expect(materializationProgress.values.count == 1)
        #expect(phases.values.contains(.preparingPhotos))
        #expect(result.statistics.totalPhotos == 1)
        #expect(result.supportedFileCount == 2)
        #expect(result.analyzedPhotoCount == 1)
        #expect(result.skippedAssets.count == 1)
        #expect(exportedDisplayInfo.values.first?.fileName == "IMG_0001.HEIC")
        #expect(exportedDisplayInfo.values.first?.sourceFile == "photos://asset/asset%2F1")
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
