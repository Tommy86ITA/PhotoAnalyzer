//
//  PhotosPickerItemAssetExporter.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import CoreTransferable
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Materializes SwiftUI Photos picker items into physical files for ExifTool-based analysis.
final class PhotosPickerItemAssetExporter {
    private let workspaceFactory: () throws -> TemporaryAssetWorkspace

    init(workspaceFactory: @escaping () throws -> TemporaryAssetWorkspace = {
        try TemporaryAssetWorkspace()
    }) {
        self.workspaceFactory = workspaceFactory
    }

    func export(items: [PhotosPickerItem]) async throws -> PhotosMaterializationResult {
        let workspace = try workspaceFactory()
        var exportedAssets: [MaterializedPhotosAsset] = []
        var skippedAssets: [PhotosAssetExportFailure] = []
        exportedAssets.reserveCapacity(items.count)

        for (index, item) in items.enumerated() {
            try Task.checkCancellation()

            let assetIdentifier = item.itemIdentifier ?? "picker-item-\(index + 1)"

            do {
                guard let importedFile = try await item.loadTransferable(type: ImportedPhotosPickerFile.self) else {
                    skippedAssets.append(PhotosAssetExportFailure(
                        assetLocalIdentifier: assetIdentifier,
                        reason: "The selected Photos item did not provide an image file."
                    ))
                    continue
                }

                defer {
                    importedFile.cleanup()
                }

                let destinationURL = workspace.fileURL(
                    preferredFilename: importedFile.preferredFilename,
                    fallbackBasename: stableFallbackName(for: assetIdentifier, index: index)
                )

                try FileManager.default.copyItem(at: importedFile.fileURL, to: destinationURL)
                exportedAssets.append(MaterializedPhotosAsset(
                    assetLocalIdentifier: assetIdentifier,
                    originalFilename: importedFile.preferredFilename,
                    fileURL: destinationURL,
                    representation: .original
                ))
            } catch is CancellationError {
                workspace.cleanup()
                throw CancellationError()
            } catch {
                skippedAssets.append(PhotosAssetExportFailure(
                    assetLocalIdentifier: assetIdentifier,
                    reason: error.localizedDescription
                ))
            }
        }

        guard !exportedAssets.isEmpty else {
            workspace.cleanup()
            throw PhotosLibraryAssetExporterError.noExportableAssets
        }

        return PhotosMaterializationResult(
            assets: exportedAssets,
            skippedAssets: skippedAssets,
            workspace: workspace
        )
    }

    private func stableFallbackName(for assetIdentifier: String, index: Int) -> String {
        let sanitizedIdentifier = assetIdentifier
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return sanitizedIdentifier.isEmpty ? "photos_asset_\(index + 1)" : sanitizedIdentifier
    }
}

private struct ImportedPhotosPickerFile: Transferable, Sendable {
    let fileURL: URL
    let cleanupURL: URL

    var preferredFilename: String? {
        let filename = fileURL.lastPathComponent
        return filename.isEmpty ? nil : filename
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { receivedFile in
            let fileManager = FileManager.default
            let stagingDirectoryURL = fileManager.temporaryDirectory
                .appendingPathComponent("PhotoAnalyzer", isDirectory: true)
                .appendingPathComponent("PickerTransfer-\(UUID().uuidString)", isDirectory: true)
            try fileManager.createDirectory(
                at: stagingDirectoryURL,
                withIntermediateDirectories: true
            )

            let sourceFilename = receivedFile.file.lastPathComponent.isEmpty
                ? "photos_picker_item"
                : receivedFile.file.lastPathComponent
            let destinationURL = stagingDirectoryURL.appendingPathComponent(
                sourceFilename,
                isDirectory: false
            )
            try fileManager.copyItem(at: receivedFile.file, to: destinationURL)

            return ImportedPhotosPickerFile(
                fileURL: destinationURL,
                cleanupURL: stagingDirectoryURL
            )
        }
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: cleanupURL)
    }
}
