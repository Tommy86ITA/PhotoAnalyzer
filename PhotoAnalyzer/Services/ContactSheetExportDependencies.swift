//
//  ContactSheetExportDependencies.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Foundation

/// Injectable collaborators used by contact sheet export.
nonisolated struct ContactSheetExportDependencies: Sendable {
    typealias LoadThumbnail = @Sendable (_ fileURL: URL, _ maxPixelSize: CGFloat) async -> ThumbnailLoadResult?

    typealias RenderPage = @Sendable (
        _ thumbnailResults: [IndexedThumbnailResult],
        _ columns: Int,
        _ sheetFileName: String,
        _ outputURL: URL
    ) throws -> ContactSheetPageRenderResult

    typealias WriteIndex = @Sendable (_ rows: [ContactSheetIndexRow], _ url: URL) throws -> Void

    let loadThumbnail: LoadThumbnail
    let renderPage: RenderPage
    let writeIndex: WriteIndex

    static let live = ContactSheetExportDependencies(
        loadThumbnail: { fileURL, maxPixelSize in
            await ThumbnailLoader().loadThumbnail(from: fileURL, maxPixelSize: maxPixelSize)
        },
        renderPage: { thumbnailResults, columns, sheetFileName, outputURL in
            try ContactSheetPageRenderer().renderPage(
                thumbnailResults,
                columns: columns,
                sheetFileName: sheetFileName,
                outputURL: outputURL
            )
        },
        writeIndex: { rows, url in
            try ContactSheetIndexWriter().write(rows, to: url)
        }
    )
}
