//
//  ThumbnailLoader.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import AppKit
import Foundation
import ImageIO

/// Loads and resizes image thumbnails for contact sheet rendering.
final class ThumbnailLoader {
    /// Creates a thumbnail loader.
    nonisolated init() {}

    /// Loads a thumbnail using the most reliable available native decoder.
    /// - Parameters:
    ///   - url: The source image URL.
    ///   - maxPixelSize: The maximum width or height in pixels.
    /// - Returns: A loaded thumbnail result, or `nil` when no preview can be created.
    nonisolated func loadThumbnail(from url: URL, maxPixelSize: CGFloat) -> ThumbnailLoadResult? {
        if shouldPreferNSImage(for: url) {
            return loadWithNSImage(from: url, maxPixelSize: maxPixelSize)
                ?? loadWithImageIO(from: url, maxPixelSize: maxPixelSize)
        }

        return loadWithImageIO(from: url, maxPixelSize: maxPixelSize)
            ?? loadWithNSImage(from: url, maxPixelSize: maxPixelSize)
    }

    nonisolated private func shouldPreferNSImage(for url: URL) -> Bool {
        ["heic", "heif"].contains(url.pathExtension.lowercased())
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

        if let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
            if hasValidPixelSize(source) {
                if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                    return ThumbnailLoadResult(
                        image: NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height)),
                        status: .cgImageSource,
                        error: "NSImage thumbnail unavailable; used CGImageSource fallback"
                    )
                }
            } else {
                print("Thumbnail fallback skipped CGImageSource for invalid image size: \(url.lastPathComponent)")
            }
        }

        return nil
    }

    nonisolated private func loadWithNSImage(from url: URL, maxPixelSize: CGFloat) -> ThumbnailLoadResult? {
        guard let image = NSImage(contentsOf: url), image.size.width > 0, image.size.height > 0 else {
            return nil
        }

        return ThumbnailLoadResult(
            image: resizedImage(image, maxPixelSize: maxPixelSize),
            status: .nsImage,
            error: nil
        )
    }

    nonisolated private func hasValidPixelSize(_ source: CGImageSource) -> Bool {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return false
        }

        let width = numericProperty(properties[kCGImagePropertyPixelWidth])
        let height = numericProperty(properties[kCGImagePropertyPixelHeight])
        return width > 0 && height > 0
    }

    nonisolated private func numericProperty(_ value: Any?) -> Double {
        if let number = value as? NSNumber {
            return number.doubleValue
        }

        if let value = value as? Double {
            return value
        }

        if let value = value as? Int {
            return Double(value)
        }

        if let value = value as? String {
            return Double(value) ?? 0
        }

        return 0
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
    case nsImage
    case cgImageSource
    case unavailable
}
