//
//  PhotoInfo.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 15/06/2026.
//

import Foundation

/// The primary photo category used by PhotoAnalyzer.
nonisolated enum PhotoType: Hashable {
    /// A regular photo without a known special classification.
    case standard

    /// A panorama photo.
    case panorama

    /// A Live Photo asset.
    case livePhoto

    /// A portrait or depth effect photo.
    case portrait

    /// A screenshot image.
    case screenshot

    /// A spatial media asset.
    case spatial

    /// A high dynamic range photo.
    case hdr
}

/// Technical and classification metadata for a single photo.
nonisolated struct PhotoInfo {
    /// The image file name.
    let fileName: String

    /// The date and time when the photo was captured.
    let captureDate: Date?

    /// The camera manufacturer.
    let cameraMake: String?

    /// The camera model.
    let cameraModel: String?

    /// The lens model or identifier.
    let lensModel: String?

    /// The focal length in millimeters.
    let focalLength: Double?

    /// The 35mm equivalent focal length in millimeters.
    let focalLength35mmEquivalent: Double?

    /// The ISO sensitivity value.
    let iso: Int?

    /// The aperture value as an f-number.
    let aperture: Double?

    /// The exposure time in seconds.
    let exposureTime: Double?

    /// The GPS latitude coordinate.
    let latitude: Double?

    /// The GPS longitude coordinate.
    let longitude: Double?

    /// The primary photo type assigned by PhotoAnalyzer.
    let photoType: PhotoType
}
