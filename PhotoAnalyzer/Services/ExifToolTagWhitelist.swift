//
//  ExifToolTagWhitelist.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation

/// Centralized list of ExifTool tags used by the file-based metadata pipeline.
enum ExifToolTagWhitelist {
    /// Tags requested from ExifTool for normal JSON metadata extraction.
    nonisolated static let tags: [String] = [
        "FileName",
        "Directory",
        "FileType",
        "MIMEType",
        "Make",
        "Model",
        "ProductName",
        "Software",
        "CreateDate",
        "ModifyDate",
        "DateTimeOriginal",
        "LensModel",
        "LensID",
        "LensMake",
        "FocalLength",
        "FocalLengthIn35mmFormat",
        "FocalLength35efl",
        "DigitalZoomRatio",
        "ScaleFactor35efl",
        "FOV",
        "ExposureTime",
        "FNumber",
        "ISO",
        "ExposureCompensation",
        "MeteringMode",
        "Flash",
        "WhiteBalance",
        "ImageWidth",
        "ImageHeight",
        "Orientation",
        "GPSLatitude",
        "GPSLongitude",
        "GPSAltitude",
        "GPSDateTime",
        "SubjectArea",
        "FocusPosition",
        "HyperfocalDistance",
        "CustomRendered",
        "HDRGainMapVersion",
        "HDRGainMapHeadroom",
        "AuxiliaryImageType"
    ]

    /// ExifTool command-line arguments for JSON extraction.
    nonisolated static let arguments: [String] = ["-json"] + tags.map { "-\($0)" }

    /// Tags requested from ExifTool for AI analysis package metadata export.
    nonisolated static let exportTags: [String] = [
        "FileName",
        "FileType",
        "FileTypeExtension",
        "MIMEType",
        "FileSize",
        "ImageWidth",
        "ImageHeight",
        "Make",
        "Model",
        "Software",
        "CreateDate",
        "DateTimeOriginal",
        "LensModel",
        "FocalLength",
        "FocalLengthIn35mmFormat",
        "DigitalZoomRatio",
        "FOV",
        "FNumber",
        "ExposureTime",
        "ISO",
        "ExposureCompensation",
        "Flash",
        "WhiteBalance",
        "GPSLatitude",
        "GPSLongitude",
        "GPSAltitude",
        "GPSImgDirection",
        "ImageCaptureType",
        "CameraType",
        "FocusPosition",
        "FocusDistanceRange",
        "AFMeasuredDepth",
        "AFConfidence",
        "HDRHeadroom",
        "HDRGain",
        "SignalToNoiseRatio",
        "ColorTemperature",
        "CustomRendered",
        "CompositeImage",
        "AuxiliaryImageType",
        "Filtered",
        "Accuracy",
        "Quality"
    ]

    /// ExifTool command-line arguments for grouped JSON export metadata extraction.
    nonisolated static let exportArguments: [String] = ["-json", "-G1"] + exportTags.map { "-\($0)" }
}
