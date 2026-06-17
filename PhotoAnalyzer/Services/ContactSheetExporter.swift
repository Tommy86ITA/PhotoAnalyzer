//
//  ContactSheetExporter.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Exports a visual contact sheet and matching TSV index for analyzed photos.
final class ContactSheetExporter {
	private enum Layout {
		nonisolated static let smallDatasetMaximumPhotoCount = 100
		nonisolated static let mediumDatasetMaximumPhotoCount = 300
		nonisolated static let largeDatasetMaximumPhotoCount = 600
		nonisolated static let smallDatasetColumns = 5
		nonisolated static let mediumDatasetColumns = 6
		nonisolated static let largeDatasetColumns = 8
		nonisolated static let extraLargeDatasetColumns = 10
		nonisolated static let maxConcurrentThumbnailLoads = 6
		nonisolated static let thumbnailSize = CGSize(width: 220, height: 160)
		nonisolated static let labelHeight: CGFloat = 26
		nonisolated static let padding: CGFloat = 24
		nonisolated static let spacing: CGFloat = 16
	}

	private let backgroundColor = NSColor.white
	private let placeholderColor = NSColor(calibratedWhite: 0.88, alpha: 1)
	private let textColor = NSColor(calibratedWhite: 0.12, alpha: 1)
	private let thumbnailLoader = ThumbnailLoader()

	/// Creates a contact sheet exporter.
	nonisolated init() {}

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
		let thumbnailResults = await PerformanceLogger.measure("Loading thumbnails") {
			await loadThumbnailResults(for: fileURLs)
		}
		let columns = columnCount(for: fileURLs.count)
		let rows = max(1, Int(ceil(Double(fileURLs.count) / Double(columns))))
		let cellWidth = Layout.thumbnailSize.width
		let cellHeight = Layout.thumbnailSize.height + Layout.labelHeight
		let canvasSize = CGSize(
			width: Layout.padding * 2 + CGFloat(columns) * cellWidth + CGFloat(columns - 1) * Layout.spacing,
			height: Layout.padding * 2 + CGFloat(rows) * cellHeight + CGFloat(rows - 1) * Layout.spacing
		)
		print("Contact sheet layout: columns=\(columns), rows=\(rows), size=\(Int(canvasSize.width))x\(Int(canvasSize.height))")

		guard let context = CGContext(
			data: nil,
			width: Int(canvasSize.width),
			height: Int(canvasSize.height),
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else {
			throw ContactSheetExporterError.couldNotCreateBitmapContext
		}

		NSGraphicsContext.saveGraphicsState()
		let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
		NSGraphicsContext.current = graphicsContext
		defer {
			NSGraphicsContext.restoreGraphicsState()
		}

		backgroundColor.setFill()
		NSRect(origin: .zero, size: canvasSize).fill()

		var indexRows: [ContactSheetIndexRow] = []
		var exportSummary = ContactSheetExportSummary()
		indexRows.reserveCapacity(fileURLs.count)

		for item in thumbnailResults {
			autoreleasepool {
				let zeroBasedIndex = item.index
				let fileURL = item.fileURL
				let row = zeroBasedIndex / columns
				let column = zeroBasedIndex % columns
				let displayIndex = zeroBasedIndex + 1
				let imageRect = thumbnailRect(row: row, column: column, canvasHeight: canvasSize.height)
				let labelRect = labelRect(row: row, column: column, canvasHeight: canvasSize.height)
				let formattedIndex = formattedIndex(displayIndex)
				let thumbnailResult = drawThumbnail(
					fileURL: fileURL,
					index: formattedIndex,
					in: imageRect,
					loadedThumbnail: item.thumbnail
				)
				exportSummary.record(thumbnailResult.status)
				drawLabel(index: formattedIndex, in: labelRect)

				indexRows.append(
					ContactSheetIndexRow(
						index: formattedIndex,
						fileName: fileURL.lastPathComponent,
						sourceFile: fileURL.path,
						row: row + 1,
						column: column + 1,
						error: thumbnailResult.error
					)
				)
			}
		}

		guard let image = context.makeImage() else {
			throw ContactSheetExporterError.couldNotCreateImage
		}

		try PerformanceLogger.measure("Writing contact_sheet.jpg") {
			try writeJPEG(image, to: paths.contactSheetURL)
		}

		try PerformanceLogger.measure("Writing index.tsv") {
			try writeIndex(indexRows, to: paths.indexURL)
		}

		print(exportSummary.logMessage)
	}

	nonisolated private func columnCount(for photoCount: Int) -> Int {
		switch photoCount {
		case ...Layout.smallDatasetMaximumPhotoCount:
			return Layout.smallDatasetColumns
		case ...Layout.mediumDatasetMaximumPhotoCount:
			return Layout.mediumDatasetColumns
		case ...Layout.largeDatasetMaximumPhotoCount:
			return Layout.largeDatasetColumns
		default:
			return Layout.extraLargeDatasetColumns
		}
	}

	nonisolated private func loadThumbnailResults(for fileURLs: [URL]) async -> [IndexedThumbnailResult] {
		let maxPixelSize = max(Layout.thumbnailSize.width, Layout.thumbnailSize.height) * 2
		var results: [IndexedThumbnailResult] = []
		results.reserveCapacity(fileURLs.count)

		var startIndex = 0
		while startIndex < fileURLs.count {
			let endIndex = min(startIndex + Layout.maxConcurrentThumbnailLoads, fileURLs.count)

			await withTaskGroup(of: IndexedThumbnailResult.self) { group in
				for index in startIndex..<endIndex {
					let fileURL = fileURLs[index]
					let thumbnailLoader = self.thumbnailLoader
					group.addTask {
						let thumbnail = await thumbnailLoader.loadThumbnail(
							from: fileURL,
							maxPixelSize: maxPixelSize
						)

						return IndexedThumbnailResult(
							index: index,
							fileURL: fileURL,
							thumbnail: thumbnail
						)
					}
				}

				for await result in group {
					results.append(result)
				}
			}

			startIndex = endIndex
		}

		return results.sorted { $0.index < $1.index }
	}

	nonisolated private func thumbnailRect(row: Int, column: Int, canvasHeight: CGFloat) -> CGRect {
		let cellHeight = Layout.thumbnailSize.height + Layout.labelHeight
		let x = Layout.padding + CGFloat(column) * (Layout.thumbnailSize.width + Layout.spacing)
		let cellTop = Layout.padding + CGFloat(row) * (cellHeight + Layout.spacing)
		let imageY = canvasHeight - cellTop - Layout.thumbnailSize.height
		return CGRect(x: x, y: imageY, width: Layout.thumbnailSize.width, height: Layout.thumbnailSize.height)
	}

	nonisolated private func labelRect(row: Int, column: Int, canvasHeight: CGFloat) -> CGRect {
		let cellHeight = Layout.thumbnailSize.height + Layout.labelHeight
		let x = Layout.padding + CGFloat(column) * (Layout.thumbnailSize.width + Layout.spacing)
		let cellTop = Layout.padding + CGFloat(row) * (cellHeight + Layout.spacing)
		let labelY = canvasHeight - cellTop - cellHeight
		return CGRect(x: x, y: labelY, width: Layout.thumbnailSize.width, height: Layout.labelHeight)
	}

	nonisolated private func drawThumbnail(
		fileURL: URL,
		index: String,
		in rect: CGRect,
		loadedThumbnail: ThumbnailLoadResult?
	) -> ThumbnailDrawResult {
		if let thumbnail = loadedThumbnail {
			let image = thumbnail.image
			let targetRect = aspectFitRect(imageSize: image.size, boundingRect: rect)
			image.draw(in: targetRect)
			return ThumbnailDrawResult(status: thumbnail.status, error: thumbnail.error)
		}

		let error = "Preview unavailable"
		print("Thumbnail unavailable: \(fileURL.lastPathComponent)")
		drawPlaceholder(in: rect, index: index, fileName: fileURL.lastPathComponent)
		return ThumbnailDrawResult(status: .unavailable, error: error)
	}

	nonisolated private func aspectFitRect(imageSize: CGSize, boundingRect: CGRect) -> CGRect {
		guard imageSize.width > 0, imageSize.height > 0 else {
			return boundingRect
		}

		let scale = min(boundingRect.width / imageSize.width, boundingRect.height / imageSize.height)
		let width = imageSize.width * scale
		let height = imageSize.height * scale
		return CGRect(
			x: boundingRect.midX - width / 2,
			y: boundingRect.midY - height / 2,
			width: width,
			height: height
		)
	}

	nonisolated private func drawPlaceholder(in rect: CGRect, index: String, fileName: String) {
		placeholderColor.setFill()
		NSBezierPath(rect: rect).fill()

		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.alignment = .center
		let attributes: [NSAttributedString.Key: Any] = [
			.font: NSFont.systemFont(ofSize: 12, weight: .regular),
			.foregroundColor: textColor,
			.paragraphStyle: paragraphStyle
		]
		let titleAttributes: [NSAttributedString.Key: Any] = [
			.font: NSFont.monospacedDigitSystemFont(ofSize: 18, weight: .semibold),
			.foregroundColor: textColor,
			.paragraphStyle: paragraphStyle
		]
		let title = index as NSString
		let file = abbreviatedFileName(fileName) as NSString
		let message = "Preview unavailable" as NSString
		let centerY = rect.midY

		title.draw(
			in: CGRect(x: rect.minX + 8, y: centerY + 16, width: rect.width - 16, height: 24),
			withAttributes: titleAttributes
		)
		file.draw(
			in: CGRect(x: rect.minX + 8, y: centerY - 8, width: rect.width - 16, height: 18),
			withAttributes: attributes
		)
		message.draw(
			in: CGRect(x: rect.minX + 8, y: centerY - 30, width: rect.width - 16, height: 18),
			withAttributes: attributes
		)
	}

	nonisolated private func drawLabel(index: String, in rect: CGRect) {
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.alignment = .center
		let attributes: [NSAttributedString.Key: Any] = [
			.font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium),
			.foregroundColor: textColor,
			.paragraphStyle: paragraphStyle
		]
		let label = index as NSString
		label.draw(in: rect.insetBy(dx: 4, dy: 4), withAttributes: attributes)
	}

	nonisolated private func writeJPEG(_ image: CGImage, to url: URL) throws {
		guard let destination = CGImageDestinationCreateWithURL(
			url as CFURL,
			UTType.jpeg.identifier as CFString,
			1,
			nil
		) else {
			throw ContactSheetExporterError.couldNotCreateJPEGDestination
		}

		let options: [CFString: Any] = [
			kCGImageDestinationLossyCompressionQuality: 0.88
		]
		CGImageDestinationAddImage(destination, image, options as CFDictionary)

		guard CGImageDestinationFinalize(destination) else {
			throw ContactSheetExporterError.couldNotWriteJPEG(url.path)
		}
	}

	nonisolated private func writeIndex(_ rows: [ContactSheetIndexRow], to url: URL) throws {
		var lines = ["Index\tFileName\tSourceFile\tRow\tColumn\tError"]
		lines += rows.map { row in
			[
				row.index,
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

	nonisolated private func formattedIndex(_ index: Int) -> String {
		ThumbnailIndexFormatter.string(from: index)
	}

	nonisolated private func abbreviatedFileName(_ fileName: String) -> String {
		guard fileName.count > 24 else {
			return fileName
		}

		let prefix = fileName.prefix(10)
		let suffix = fileName.suffix(10)
		return "\(prefix)...\(suffix)"
	}
}

private struct ContactSheetIndexRow {
	let index: String
	let fileName: String
	let sourceFile: String
	let row: Int
	let column: Int
	let error: String?
}

private struct IndexedThumbnailResult {
	let index: Int
	let fileURL: URL
	let thumbnail: ThumbnailLoadResult?
}

private struct ThumbnailDrawResult {
	let status: ThumbnailStatus
	let error: String?
}

nonisolated private struct ContactSheetExportSummary {
	private(set) var quickLookCount = 0
	private(set) var nsImageCount = 0
	private(set) var cgImageSourceCount = 0
	private(set) var unavailableCount = 0

	mutating func record(_ status: ThumbnailStatus) {
		switch status {
		case .quickLook:
			quickLookCount += 1
		case .nsImage:
			nsImageCount += 1
		case .cgImageSource:
			cgImageSourceCount += 1
		case .unavailable:
			unavailableCount += 1
		}
	}

	var logMessage: String {
		"Contact sheet thumbnails: QuickLook=\(quickLookCount), NSImage=\(nsImageCount), CGImageSource=\(cgImageSourceCount), unavailable=\(unavailableCount)"
	}
}

private enum ContactSheetExporterError: LocalizedError {
	case couldNotCreateBitmapContext
	case couldNotCreateImage
	case couldNotOpenImage(String)
	case couldNotCreateThumbnail(String)
	case couldNotCreateJPEGDestination
	case couldNotWriteJPEG(String)

	var errorDescription: String? {
		switch self {
		case .couldNotCreateBitmapContext:
			return "Could not create the contact sheet bitmap context."
		case .couldNotCreateImage:
			return "Could not create the contact sheet image."
		case .couldNotOpenImage(let fileName):
			return "Could not open image \(fileName)."
		case .couldNotCreateThumbnail(let fileName):
			return "Could not create thumbnail for \(fileName)."
		case .couldNotCreateJPEGDestination:
			return "Could not create the contact sheet JPEG destination."
		case .couldNotWriteJPEG(let path):
			return "Could not write contact sheet JPEG at \(path)."
		}
	}
}
