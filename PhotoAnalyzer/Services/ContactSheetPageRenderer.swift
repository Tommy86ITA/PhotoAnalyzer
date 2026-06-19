//
//  ContactSheetPageRenderer.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import AppKit
import Foundation

nonisolated struct ContactSheetPageRenderer {
    private let backgroundColor = NSColor.white
    private let placeholderColor = NSColor(calibratedWhite: 0.88, alpha: 1)
    private let textColor = NSColor(calibratedWhite: 0.12, alpha: 1)
    private let jpegWriter = ContactSheetJPEGWriter()

    nonisolated func renderPage(
        _ thumbnailResults: [IndexedThumbnailResult],
        columns: Int,
        sheetFileName: String,
        outputURL: URL
    ) throws -> ContactSheetPageRenderResult {
        let rows = max(1, Int(ceil(Double(thumbnailResults.count) / Double(columns))))
        let cellWidth = ContactSheetLayout.thumbnailSize.width
        let cellHeight = ContactSheetLayout.thumbnailSize.height + ContactSheetLayout.labelHeight
        let canvasSize = CGSize(
            width: ContactSheetLayout.padding * 2 + CGFloat(columns) * cellWidth + CGFloat(columns - 1) * ContactSheetLayout.spacing,
            height: ContactSheetLayout.padding * 2 + CGFloat(rows) * cellHeight + CGFloat(rows - 1) * ContactSheetLayout.spacing
        )
        print("Contact sheet page: file=\(sheetFileName), columns=\(columns), rows=\(rows), size=\(Int(canvasSize.width))x\(Int(canvasSize.height))")

        guard canvasSize.width <= ContactSheetLayout.maximumJPEGDimension,
              canvasSize.height <= ContactSheetLayout.maximumJPEGDimension else {
            throw ContactSheetExporterError.contactSheetPageTooLarge(sheetFileName)
        }

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
        var summary = ContactSheetExportSummary()
        indexRows.reserveCapacity(thumbnailResults.count)

        for (pageOffset, item) in thumbnailResults.enumerated() {
            try Task.checkCancellation()

            autoreleasepool {
                let fileURL = item.fileURL
                let row = pageOffset / columns
                let column = pageOffset % columns
                let displayIndex = item.index + 1
                let imageRect = thumbnailRect(row: row, column: column, canvasHeight: canvasSize.height)
                let labelRect = labelRect(row: row, column: column, canvasHeight: canvasSize.height)
                let formattedIndex = ThumbnailIndexFormatter.string(from: displayIndex)
                let thumbnailResult = drawThumbnail(
                    fileURL: fileURL,
                    index: formattedIndex,
                    in: imageRect,
                    loadedThumbnail: item.thumbnail
                )
                summary.record(thumbnailResult.status)
                drawLabel(index: formattedIndex, in: labelRect)

                indexRows.append(
                    ContactSheetIndexRow(
                        index: formattedIndex,
                        sheet: sheetFileName,
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

        try Task.checkCancellation()
        try PerformanceLogger.measure("Writing \(sheetFileName)") {
            try jpegWriter.write(image, to: outputURL)
        }

        return ContactSheetPageRenderResult(indexRows: indexRows, summary: summary)
    }

    nonisolated private func thumbnailRect(row: Int, column: Int, canvasHeight: CGFloat) -> CGRect {
        let cellHeight = ContactSheetLayout.thumbnailSize.height + ContactSheetLayout.labelHeight
        let x = ContactSheetLayout.padding + CGFloat(column) * (ContactSheetLayout.thumbnailSize.width + ContactSheetLayout.spacing)
        let cellTop = ContactSheetLayout.padding + CGFloat(row) * (cellHeight + ContactSheetLayout.spacing)
        let imageY = canvasHeight - cellTop - ContactSheetLayout.thumbnailSize.height
        return CGRect(x: x, y: imageY, width: ContactSheetLayout.thumbnailSize.width, height: ContactSheetLayout.thumbnailSize.height)
    }

    nonisolated private func labelRect(row: Int, column: Int, canvasHeight: CGFloat) -> CGRect {
        let cellHeight = ContactSheetLayout.thumbnailSize.height + ContactSheetLayout.labelHeight
        let x = ContactSheetLayout.padding + CGFloat(column) * (ContactSheetLayout.thumbnailSize.width + ContactSheetLayout.spacing)
        let cellTop = ContactSheetLayout.padding + CGFloat(row) * (cellHeight + ContactSheetLayout.spacing)
        let labelY = canvasHeight - cellTop - cellHeight
        return CGRect(x: x, y: labelY, width: ContactSheetLayout.thumbnailSize.width, height: ContactSheetLayout.labelHeight)
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

    nonisolated private func abbreviatedFileName(_ fileName: String) -> String {
        guard fileName.count > 24 else {
            return fileName
        }

        let prefix = fileName.prefix(10)
        let suffix = fileName.suffix(10)
        return "\(prefix)...\(suffix)"
    }
}
