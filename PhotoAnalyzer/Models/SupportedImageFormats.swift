//
//  SupportedImageFormats.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation

/// Supported image file formats for folder scanning and metadata experiments.
nonisolated enum SupportedImageFormats {
    /// Lowercase file extensions accepted by PhotoAnalyzer.
	static let extensions: Set<String> = [
		"heic", "heif",
		"jpg", "jpeg",
		"png",
		"tif", "tiff",

		"dng",
		"raw",
		"arw",
		"cr2",
		"cr3",
		"nef",
		"x3f",
		"orf",
		"rw2",
		"3fr"
	]

    /// Returns whether a file URL has a supported image extension.
    /// - Parameter url: The file URL to inspect.
    /// - Returns: `true` when the extension is supported.
    static func contains(_ url: URL) -> Bool {
        extensions.contains(url.pathExtension.lowercased())
    }
}
