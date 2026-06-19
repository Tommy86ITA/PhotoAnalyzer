//
//  ContactSheetExporter.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation

/// Exports a visual contact sheet and matching TSV index for analyzed photos.
final class ContactSheetExporter {
	private let dependencies: ContactSheetExportDependencies

	/// Creates a contact sheet exporter.
	nonisolated init(dependencies: ContactSheetExportDependencies = .live) {
		self.dependencies = dependencies
	}

	/// Exports `contact_sheet.jpg` and `index.tsv` into the package folder.
	/// - Parameters:
	///   - folderURL: The original folder URL analyzed by PhotoAnalyzer.
	///   - fileURLs: The analyzed image files in stable visual order.
	///   - paths: The output AI package paths.
	/// - Throws: File system or image encoding errors.
	nonisolated func exportContactSheet(
		folderURL: URL,
		fileURLs: [URL],
		paths: AIAnalysisPackagePaths
	) async throws {
		try await exportContactSheet(
			folderURL: folderURL,
			fileURLs: fileURLs,
			paths: paths,
			displayInfoByFileURL: [:],
			progressHandler: nil
		)
	}

	/// Exports `contact_sheet.jpg` and `index.tsv` into the package folder.
	/// - Parameters:
	///   - folderURL: The original folder URL analyzed by PhotoAnalyzer.
	///   - fileURLs: The analyzed image files in stable visual order.
	///   - paths: The output AI package paths.
	///   - progressHandler: Optional progress callback for contact sheet export work.
	/// - Throws: File system or image encoding errors.
	nonisolated func exportContactSheet(
		folderURL: URL,
		fileURLs: [URL],
		paths: AIAnalysisPackagePaths,
		displayInfoByFileURL: [URL: SourceFileDisplayInfo] = [:],
		progressHandler: (@Sendable (ProgressSnapshot) -> Void)?
	) async throws {
		try Task.checkCancellation()
		let columns = try columnCount(for: fileURLs.count)
		let rowsPerSheet = ContactSheetLayout.maximumRowsPerSheet
		let itemsPerSheet = max(1, columns * rowsPerSheet)
		let estimatedSheetCount = max(1, Int(ceil(Double(fileURLs.count) / Double(itemsPerSheet))))
		let totalProgressUnits = Int64(fileURLs.count + estimatedSheetCount + 1)

		let thumbnailResults = try await PerformanceLogger.measure("Loading thumbnails") {
			try await loadThumbnailResults(
				for: fileURLs,
				displayInfoByFileURL: displayInfoByFileURL,
				totalProgressUnits: totalProgressUnits,
				progressHandler: progressHandler
			)
		}
		try Task.checkCancellation()

		let sheetCount = max(1, Int(ceil(Double(thumbnailResults.count) / Double(itemsPerSheet))))
		var indexRows: [ContactSheetIndexRow] = []
		var exportSummary = ContactSheetExportSummary()
		indexRows.reserveCapacity(fileURLs.count)
		try removeExistingContactSheets(in: paths.packageURL)

		for sheetIndex in 0..<sheetCount {
			try Task.checkCancellation()
			let pageStart = sheetIndex * itemsPerSheet
			let pageEnd = min(pageStart + itemsPerSheet, thumbnailResults.count)
			let pageResults = Array(thumbnailResults[pageStart..<pageEnd])
			let sheetFileName = sheetCount == 1
				? AIAnalysisPackagePaths.contactSheetFileName
				: ContactSheetLayout.pageFileName(sheetIndex + 1)
			let sheetURL = sheetCount == 1
				? paths.contactSheetURL
				: paths.packageURL.appendingPathComponent(sheetFileName)

			let renderResult = try dependencies.renderPage(
				pageResults,
				columns,
				sheetFileName,
				sheetURL
			)
			exportSummary.merge(renderResult.summary)
			indexRows.append(contentsOf: renderResult.indexRows)
			progressHandler?(
				ProgressSnapshot(
					completedUnitCount: Int64(fileURLs.count + sheetIndex + 1),
					totalUnitCount: totalProgressUnits,
					message: "Writing contact sheet \(sheetIndex + 1) of \(sheetCount)..."
				)
			)

			if sheetIndex == 0 && sheetCount > 1 {
				try? FileManager.default.removeItem(at: paths.contactSheetURL)
				try FileManager.default.copyItem(at: sheetURL, to: paths.contactSheetURL)
			}
		}

		try Task.checkCancellation()
		try PerformanceLogger.measure("Writing index.tsv") {
			try dependencies.writeIndex(indexRows, paths.indexURL)
		}
		progressHandler?(
			ProgressSnapshot(
				completedUnitCount: totalProgressUnits,
				totalUnitCount: totalProgressUnits,
				message: "Writing index.tsv..."
			)
		)

		print("Contact sheet pages: \(sheetCount)")
		print(exportSummary.logMessage)
	}

	nonisolated private func columnCount(for photoCount: Int) throws -> Int {
		let preferredColumns = ContactSheetLayout.columnCount(for: photoCount)

		let maximumColumnsForSafeWidth = max(
			1,
			Int((ContactSheetLayout.maximumJPEGDimension - ContactSheetLayout.padding * 2 + ContactSheetLayout.spacing) / (ContactSheetLayout.thumbnailSize.width + ContactSheetLayout.spacing))
		)

		guard preferredColumns <= maximumColumnsForSafeWidth else {
			throw ContactSheetExporterError.contactSheetTooLarge(photoCount)
		}

		return preferredColumns
	}

	nonisolated private func removeExistingContactSheets(in packageURL: URL) throws {
		let fileManager = FileManager.default
		let existingFiles = try fileManager.contentsOfDirectory(
			at: packageURL,
			includingPropertiesForKeys: nil
		)

		for fileURL in existingFiles {
			let fileName = fileURL.lastPathComponent
			let isLegacySheet = fileName == AIAnalysisPackagePaths.contactSheetFileName
			let isPaginatedSheet = fileName.hasPrefix("contact_sheet_") && fileName.hasSuffix(".jpg")

			if isLegacySheet || isPaginatedSheet {
				try fileManager.removeItem(at: fileURL)
			}
		}
	}

	nonisolated private func loadThumbnailResults(
		for fileURLs: [URL],
		displayInfoByFileURL: [URL: SourceFileDisplayInfo],
		totalProgressUnits: Int64,
		progressHandler: (@Sendable (ProgressSnapshot) -> Void)?
	) async throws -> [IndexedThumbnailResult] {
		let maxPixelSize = max(ContactSheetLayout.thumbnailSize.width, ContactSheetLayout.thumbnailSize.height) * 2
		var results: [IndexedThumbnailResult] = []
		results.reserveCapacity(fileURLs.count)

		var startIndex = 0
		while startIndex < fileURLs.count {
			try Task.checkCancellation()

			let endIndex = min(startIndex + ContactSheetLayout.maxConcurrentThumbnailLoads, fileURLs.count)

			try await withThrowingTaskGroup(of: IndexedThumbnailResult.self) { group in
				for index in startIndex..<endIndex {
					let fileURL = fileURLs[index]
					let loadThumbnail = dependencies.loadThumbnail
					group.addTask {
						try Task.checkCancellation()
						let thumbnail = await loadThumbnail(fileURL, maxPixelSize)
						try Task.checkCancellation()

						return IndexedThumbnailResult(
							index: index,
							fileURL: fileURL,
							displayInfo: displayInfoByFileURL[fileURL],
							thumbnail: thumbnail
						)
					}
				}

				for try await result in group {
					results.append(result)
					progressHandler?(
						ProgressSnapshot(
							completedUnitCount: Int64(results.count),
							totalUnitCount: totalProgressUnits,
							message: "Loading thumbnails..."
						)
					)
				}
			}

			startIndex = endIndex
		}

		return results.sorted { $0.index < $1.index }
	}
}
