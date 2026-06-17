//
//  PhotoInfoMapper.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation

/// Maps raw ExifTool metadata into the lightweight `PhotoInfo` model used by UI and statistics.
final class PhotoInfoMapper {
    /// Creates a photo information mapper.
    nonisolated init() {}

    /// Builds a `PhotoInfo` model from decoded ExifTool metadata.
    /// - Parameters:
    ///   - metadata: The decoded ExifTool metadata.
    ///   - fallbackFileURL: The file URL used when ExifTool does not provide a file name.
    /// - Returns: A photo information model populated from ExifTool tags.
    nonisolated func photoInfo(from metadata: ExifToolMetadata, fallbackFileURL: URL) -> PhotoInfo {
        PhotoInfo(
            fileName: metadata.fileName ?? fallbackFileURL.lastPathComponent,
            captureDate: captureDate(from: metadata),
            cameraMake: metadata.make,
            cameraModel: metadata.model ?? metadata.productName,
            lensModel: metadata.lensModel ?? metadata.lensID,
            focalLength: ExifToolValueParser.double(from: metadata.focalLength),
            focalLength35mmEquivalent: ExifToolValueParser.double(from: metadata.focalLengthIn35mmFormat)
                ?? ExifToolValueParser.double(from: metadata.focalLength35efl),
            iso: ExifToolValueParser.int(from: metadata.iso),
            aperture: ExifToolValueParser.double(from: metadata.fNumber),
            exposureTime: ExifToolValueParser.exposureTime(from: metadata.exposureTime),
            latitude: GpsValueParser.parseCoordinate(metadata.gpsLatitude),
            longitude: GpsValueParser.parseCoordinate(metadata.gpsLongitude),
            photoType: mapPhotoType(from: metadata)
        )
    }

    /// Maps ExifTool metadata to the primary `PhotoType` used by PhotoAnalyzer.
    /// - Parameter metadata: The decoded ExifTool metadata.
    /// - Returns: The mapped photo type.
    nonisolated private func mapPhotoType(from metadata: ExifToolMetadata) -> PhotoType {
        if metadata.customRendered?.caseInsensitiveCompare("Portrait") == .orderedSame {
            return .portrait
        }

        if metadata.customRendered?.caseInsensitiveCompare("Panorama") == .orderedSame {
            return .panorama
        }

        if hasHDRMetadata(metadata) {
            return .hdr
        }

        return .standard
    }

    /// Returns whether ExifTool metadata exposes known HDR gain map indicators.
    /// - Parameter metadata: The decoded ExifTool metadata.
    /// - Returns: `true` when HDR metadata is present.
    nonisolated private func hasHDRMetadata(_ metadata: ExifToolMetadata) -> Bool {
        if metadata.hdrGainMapVersion != nil || metadata.hdrGainMapHeadroom != nil {
            return true
        }

        return metadata.auxiliaryImageType?
            .range(of: "hdrgainmap", options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    /// Reads a capture date from ExifTool date fields.
    /// - Parameter metadata: The decoded ExifTool metadata.
    /// - Returns: The parsed date, or `nil` when unavailable.
    nonisolated private func captureDate(from metadata: ExifToolMetadata) -> Date? {
        guard let dateText = metadata.dateTimeOriginal ?? metadata.createDate else {
            return nil
        }

        return exifDateFormatter.date(from: dateText)
    }

    /// A formatter for common ExifTool date strings.
    nonisolated private var exifDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }
}
