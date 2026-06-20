//
//  ThumbnailLoader.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import AppKit
import Foundation
import ImageIO
import QuickLookThumbnailing

/// Loads and resizes image thumbnails for contact sheet rendering.
final class ThumbnailLoader {
	/// Creates a thumbnail loader.
	nonisolated init() {}

	/// Loads a thumbnail using the most reliable available native decoder.
	/// - Parameters:
	///   - url: The source image URL.
	///   - maxPixelSize: The maximum width or height in pixels.
	/// - Returns: A loaded thumbnail result, or `nil` when no preview can be created.
	nonisolated func loadThumbnail(from url: URL, maxPixelSize: CGFloat) async -> ThumbnailLoadResult? {
		if shouldPreferQuickLook(for: url) {
			return await loadWithQuickLook(from: url, maxPixelSize: maxPixelSize)
				?? loadWithNSImage(from: url, maxPixelSize: maxPixelSize)
				?? loadWithImageIO(from: url, maxPixelSize: maxPixelSize)
		}

		return loadWithImageIO(from: url, maxPixelSize: maxPixelSize)
			?? loadWithNSImage(from: url, maxPixelSize: maxPixelSize)
	}

	nonisolated private func shouldPreferQuickLook(for url: URL) -> Bool {
		[
			"heic", "heif",
			"dng", "raw", "arw", "cr2", "cr3", "nef", "x3f", "orf", "rw2", "3fr"
		].contains(url.pathExtension.lowercased())
	}

	nonisolated private func loadWithQuickLook(from url: URL, maxPixelSize: CGFloat) async -> ThumbnailLoadResult? {
		await withCheckedContinuation { continuation in
			let request = QLThumbnailGenerator.Request(
				fileAt: url,
				size: CGSize(width: maxPixelSize, height: maxPixelSize),
				scale: 1,
				representationTypes: .thumbnail
			)
			request.iconMode = false

			QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, error in
				guard let thumbnail else {
					continuation.resume(returning: nil)
					return
				}

				let originalImage = thumbnail.nsImage
				guard originalImage.size.width > 0, originalImage.size.height > 0 else {
					continuation.resume(returning: nil)
					return
				}
				let nsImage = self.autoreleaseResize(originalImage, maxPixelSize: maxPixelSize)

				continuation.resume(
					returning: ThumbnailLoadResult(
						image: nsImage,
						status: .quickLook,
						error: error.map { "QuickLook generated thumbnail with warning: \($0.localizedDescription)" }
					)
				)
			}
		}
	}

	nonisolated private func loadWithImageIO(from url: URL, maxPixelSize: CGFloat) -> ThumbnailLoadResult? {
		var options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
			kCGImageSourceCreateThumbnailWithTransform: true,
			kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize)
		]

		if #available(macOS 14.0, *) {
			options[kCGImageSourceDecodeRequest] = kCGImageSourceDecodeToSDR
		}

		if #available(macOS 15.0, *) {
			options[kCGImageSourceGenerateImageSpecificLumaScaling] = false
		}

		if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
		   CGImageSourceGetCount(source) > 0,
		   let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
			return ThumbnailLoadResult(
				image: NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height)),
				status: .cgImageSource,
				error: "NSImage thumbnail unavailable; used CGImageSource fallback"
			)
			}

		return nil
	}

	nonisolated private func loadWithNSImage(from url: URL, maxPixelSize: CGFloat) -> ThumbnailLoadResult? {
		guard let image = NSImage(contentsOf: url), image.size.width > 0, image.size.height > 0 else {
			return nil
		}

		return ThumbnailLoadResult(
			image: autoreleaseResize(image, maxPixelSize: maxPixelSize),
			status: .nsImage,
			error: nil
		)
	}

	/// Limits temporary AppKit/CoreGraphics allocations during large thumbnail batches.
	nonisolated private func autoreleaseResize(_ image: NSImage, maxPixelSize: CGFloat) -> NSImage {
		autoreleasepool {
			resizedImage(image, maxPixelSize: maxPixelSize)
		}
	}

	nonisolated private func resizedImage(_ image: NSImage, maxPixelSize: CGFloat) -> NSImage {
		let scale = min(maxPixelSize / image.size.width, maxPixelSize / image.size.height, 1)
		let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
		let resizedImage = NSImage(size: targetSize)

		resizedImage.lockFocus()
		image.draw(
			in: CGRect(origin: .zero, size: targetSize),
			from: CGRect(origin: .zero, size: image.size),
			operation: .copy,
			fraction: 1
		)
		resizedImage.unlockFocus()

		return resizedImage
	}
}

/// The result of a thumbnail load attempt.
nonisolated struct ThumbnailLoadResult {
	let image: NSImage
	let status: ThumbnailStatus
	let error: String?
}

/// The decoder path used to create a thumbnail.
enum ThumbnailStatus {
	case quickLook
	case nsImage
	case cgImageSource
	case unavailable
}
