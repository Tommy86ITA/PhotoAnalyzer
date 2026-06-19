//
//  ContactSheetJPEGWriter.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated struct ContactSheetJPEGWriter {
    nonisolated func write(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ContactSheetExporterError.couldNotCreateJPEGDestination
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: ContactSheetLayout.jpegCompressionQuality
        ]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ContactSheetExporterError.couldNotWriteJPEG(url.path)
        }
    }
}
