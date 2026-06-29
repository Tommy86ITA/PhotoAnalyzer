//
//  AIAnalysisPackageExporter.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation
import OSLog

/// Exports normalized analysis data for downstream AI workflows.
final class AIAnalysisPackageExporter {
	/// Creates an AI analysis package exporter.
	nonisolated init() {}

	/// Creates the AI package folder and writes the JSON payloads.
	/// - Parameters:
	///   - folderURL: The original folder URL analyzed by PhotoAnalyzer.
	///   - metadata: The rich export metadata produced by the analysis pipeline.
	///   - sourceFileURLs: The analyzed source image files in contact sheet order.
	///   - statistics: The aggregate statistics produced from the photos.
	///   - paths: The package paths used for the exported files.
	/// - Returns: The package paths used by subsequent export phases.
	/// - Throws: File system or JSON encoding errors.
	nonisolated func exportDataFiles(
		for folderURL: URL,
		metadata: [ExportPhotoMetadata],
		sourceFileURLs: [URL],
		statistics: PhotoStatistics,
		paths: AIAnalysisPackagePaths
	) throws -> AIAnalysisPackagePaths {
		try exportDataFiles(
			for: folderURL,
			metadata: metadata,
			sourceFileURLs: sourceFileURLs,
			statistics: statistics,
			paths: paths,
			displayInfoByFileURL: [:],
			progressHandler: nil
		)
	}

	/// Creates the AI package folder and writes the JSON payloads.
	/// - Parameters:
	///   - folderURL: The original folder URL analyzed by PhotoAnalyzer.
	///   - metadata: The rich export metadata produced by the analysis pipeline.
	///   - sourceFileURLs: The analyzed source image files in contact sheet order.
	///   - statistics: The aggregate statistics produced from the photos.
	///   - paths: The package paths used for the exported files.
	///   - progressHandler: Optional progress callback for written package data files.
	/// - Returns: The package paths used by subsequent export phases.
	/// - Throws: File system or JSON encoding errors.
	nonisolated func exportDataFiles(
		for folderURL: URL,
		metadata: [ExportPhotoMetadata],
		sourceFileURLs: [URL],
		statistics: PhotoStatistics,
		paths: AIAnalysisPackagePaths,
		displayInfoByFileURL: [URL: SourceFileDisplayInfo] = [:],
		progressHandler: (@Sendable (ProgressSnapshot) -> Void)?
	) throws -> AIAnalysisPackagePaths {
		try Task.checkCancellation()
		AppLogger.export.info("AI package path: \(paths.packageURL.path, privacy: .private)")
		try FileManager.default.createDirectory(at: paths.packageURL, withIntermediateDirectories: true)

		let jsonWriter = JSONFileWriter()

		try PerformanceLogger.measure("Exporting metadata.json") {
			try Task.checkCancellation()
			let indexedMetadata = metadataWithThumbnailIndexes(
				metadata,
				sourceFileURLs: sourceFileURLs,
				displayInfoByFileURL: displayInfoByFileURL
			)
			try jsonWriter.write(indexedMetadata, to: paths.metadataURL)
		}
		progressHandler?(
			ProgressSnapshot(
				completedUnitCount: 1,
				totalUnitCount: 2,
				message: "Exporting metadata.json..."
			)
		)

		try PerformanceLogger.measure("Exporting statistics.json") {
			try Task.checkCancellation()
			let statisticsPayload = AIStatisticsPayload(statistics: statistics)
			try jsonWriter.write(statisticsPayload, to: paths.statisticsURL)
		}
		progressHandler?(
			ProgressSnapshot(
				completedUnitCount: 2,
				totalUnitCount: 2,
				message: "Exporting statistics.json..."
			)
		)

		try Task.checkCancellation()
		return paths
	}

	/// Adds contact sheet thumbnail indexes to metadata records.
	/// - Parameters:
	///   - metadata: ExifTool metadata records.
	///   - sourceFileURLs: The analyzed source image files in contact sheet order.
	/// - Returns: Metadata records augmented with contact sheet indexes.
	nonisolated private func metadataWithThumbnailIndexes(
		_ metadata: [ExportPhotoMetadata],
		sourceFileURLs: [URL],
		displayInfoByFileURL: [URL: SourceFileDisplayInfo]
	) -> [IndexedExportPhotoMetadata] {
		var indexByPath: [String: String] = [:]
		var indexByFileName: [String: String] = [:]
		var contactSheetPageByPath: [String: Int] = [:]
		var contactSheetPageByFileName: [String: Int] = [:]
		var contactSheetFileByPath: [String: String] = [:]
		var contactSheetFileByFileName: [String: String] = [:]
		let columns = ContactSheetLayout.columnCount(for: sourceFileURLs.count)
		let itemsPerSheet = max(1, columns * ContactSheetLayout.maximumRowsPerSheet)
		let sheetCount = max(1, Int(ceil(Double(sourceFileURLs.count) / Double(itemsPerSheet))))

		for (offset, url) in sourceFileURLs.enumerated() {
			let index = ThumbnailIndexFormatter.string(from: offset + 1)
			let page = offset / itemsPerSheet + 1
			let sheetFile = sheetCount == 1
				? AIAnalysisPackagePaths.contactSheetFileName
				: ContactSheetLayout.pageFileName(page)
			let displayInfo = displayInfoByFileURL[url]
			indexByPath[url.path] = index
			indexByFileName[displayInfo?.fileName ?? url.lastPathComponent] = index
			contactSheetPageByPath[url.path] = page
			contactSheetPageByFileName[displayInfo?.fileName ?? url.lastPathComponent] = page
			contactSheetFileByPath[url.path] = sheetFile
			contactSheetFileByFileName[displayInfo?.fileName ?? url.lastPathComponent] = sheetFile
		}

		return metadata.enumerated().map { offset, metadata in
			let sourceFileURL = offset < sourceFileURLs.count ? sourceFileURLs[offset] : nil
			let displayInfo = sourceFileURL.flatMap { displayInfoByFileURL[$0] }
			let thumbnailIndex = metadata.sourceFile.flatMap { indexByPath[$0] }
				?? metadata.fileName.flatMap { indexByFileName[$0] }
				?? sourceFileURL.flatMap { indexByPath[$0.path] }
			let contactSheetPage = metadata.sourceFile.flatMap { contactSheetPageByPath[$0] }
				?? metadata.fileName.flatMap { contactSheetPageByFileName[$0] }
				?? sourceFileURL.flatMap { contactSheetPageByPath[$0.path] }
			let contactSheetFile = metadata.sourceFile.flatMap { contactSheetFileByPath[$0] }
				?? metadata.fileName.flatMap { contactSheetFileByFileName[$0] }
				?? sourceFileURL.flatMap { contactSheetFileByPath[$0.path] }

			return IndexedExportPhotoMetadata(
				metadata: metadata,
				thumbnailIndex: thumbnailIndex,
				contactSheetPage: contactSheetPage,
				contactSheetFile: contactSheetFile,
				displayInfo: displayInfo
			)
		}
	}

	/// Generates the package contact sheet and index TSV.
	/// - Parameters:
	///   - folderURL: The original folder URL analyzed by PhotoAnalyzer.
	///   - sourceFileURLs: The analyzed source image files in contact sheet order.
	///   - paths: The package paths created by `exportDataFiles`.
	/// - Throws: File system or image encoding errors.
	nonisolated func exportContactSheet(
		folderURL: URL,
		sourceFileURLs: [URL],
		paths: AIAnalysisPackagePaths
	) async throws {
		try await exportContactSheet(
			folderURL: folderURL,
			sourceFileURLs: sourceFileURLs,
			paths: paths,
			displayInfoByFileURL: [:],
			progressHandler: nil
		)
	}

	/// Generates the package contact sheet and index TSV.
	/// - Parameters:
	///   - folderURL: The original folder URL analyzed by PhotoAnalyzer.
	///   - sourceFileURLs: The analyzed source image files in contact sheet order.
	///   - paths: The package paths created by `exportDataFiles`.
	///   - progressHandler: Optional progress callback for thumbnail/contact sheet export.
	/// - Throws: File system or image encoding errors.
	nonisolated func exportContactSheet(
		folderURL: URL,
		sourceFileURLs: [URL],
		paths: AIAnalysisPackagePaths,
		displayInfoByFileURL: [URL: SourceFileDisplayInfo] = [:],
		progressHandler: (@Sendable (ProgressSnapshot) -> Void)?
	) async throws {
		try await PerformanceLogger.measure("Exporting contact sheet and index") {
			let contactSheetExporter = ContactSheetExporter()
			try await contactSheetExporter.exportContactSheet(
				folderURL: folderURL,
				fileURLs: sourceFileURLs,
				paths: paths,
				displayInfoByFileURL: displayInfoByFileURL,
				progressHandler: progressHandler
			)
		}
	}

	/// Creates a ZIP archive for the generated package folder.
	/// - Parameter paths: The package paths created by previous export phases.
	/// - Returns: The created ZIP archive URL.
	/// - Throws: File system or archive creation errors.
	nonisolated func archivePackage(paths: AIAnalysisPackagePaths) throws -> URL {
		try archivePackage(paths: paths, progressHandler: nil)
	}

	/// Creates a ZIP archive for the generated package folder.
	/// - Parameters:
	///   - paths: The package paths created by previous export phases.
	///   - progressHandler: Optional progress callback for archive creation.
	/// - Returns: The created ZIP archive URL.
	/// - Throws: File system or archive creation errors.
	nonisolated func archivePackage(
		paths: AIAnalysisPackagePaths,
		progressHandler: (@Sendable (ProgressSnapshot) -> Void)?
	) throws -> URL {
		try PerformanceLogger.measure("Archiving AI package") {
			let archiver = AIAnalysisPackageArchiver()
			return try archiver.archivePackage(
				at: paths.packageURL,
				to: paths.archiveURL,
				progressHandler: progressHandler
			)
		}
	}
}
