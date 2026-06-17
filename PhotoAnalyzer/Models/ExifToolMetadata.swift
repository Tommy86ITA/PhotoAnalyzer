//
//  ExifToolMetadata.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation

/// Raw metadata decoded from the JSON output produced by ExifTool.
struct ExifToolMetadata: Codable, Sendable {
    /// The original source file path reported by ExifTool.
    let sourceFile: String?

    /// The file name reported by ExifTool.
    let fileName: String?

    /// The file type reported by ExifTool.
    let fileType: String?

    /// The MIME type reported by ExifTool.
    let mimeType: String?

    /// The camera manufacturer.
    let make: String?

    /// The camera model.
    let model: String?

    /// The lens model.
    let lensModel: String?

    /// The lens identifier.
    let lensID: String?

    /// The file or media creation date.
    let createDate: String?

    /// The original capture date.
    let dateTimeOriginal: String?

    /// The custom rendering mode interpreted by ExifTool.
    let customRendered: String?

    /// The scene capture type interpreted by ExifTool.
    let sceneCaptureType: String?

    /// The image capture type interpreted by ExifTool.
    let imageCaptureType: String?

    /// The physical focal length.
    let focalLength: String?

    /// The 35mm equivalent focal length.
    let focalLengthIn35mmFormat: String?

    /// The focal length string that may include 35mm equivalent information.
    let focalLength35efl: String?

    /// The ISO sensitivity value.
    let iso: String?

    /// The aperture f-number.
    let fNumber: String?

    /// The exposure time.
    let exposureTime: String?

    /// The GPS latitude value reported by ExifTool.
    let gpsLatitude: String?

    /// The GPS longitude value reported by ExifTool.
    let gpsLongitude: String?

    /// The GPS altitude value reported by ExifTool.
    let gpsAltitude: String?

    /// The combined GPS position value.
    let gpsPosition: String?

    /// The image width in pixels.
    let imageWidth: String?

    /// The image height in pixels.
    let imageHeight: String?

    /// The image megapixel count.
    let megapixels: String?

    /// The product name reported by camera-specific metadata, such as DJI files.
    let productName: String?

    /// The relative altitude reported by drone metadata.
    let relativeAltitude: String?

    /// The absolute altitude reported by drone metadata.
    let absoluteAltitude: String?

    /// The gimbal pitch angle reported by drone metadata.
    let gimbalPitchDegree: String?

    /// The gimbal yaw angle reported by drone metadata.
    let gimbalYawDegree: String?

    /// The gimbal roll angle reported by drone metadata.
    let gimbalRollDegree: String?

    /// The flight pitch angle reported by drone metadata.
    let flightPitchDegree: String?

    /// The flight yaw angle reported by drone metadata.
    let flightYawDegree: String?

    /// The flight roll angle reported by drone metadata.
    let flightRollDegree: String?

    /// The Apple HDR gain map version, when present.
    let hdrGainMapVersion: String?

    /// The Apple HDR gain map headroom value, when present.
    let hdrGainMapHeadroom: String?

    /// The auxiliary image type, when present.
    let auxiliaryImageType: String?

    /// The simulated aperture value, when present.
    let simulatedAperture: String?

    /// The image effect strength, when present.
    let effectStrength: String?

    /// The depth data version, when present.
    let depthDataVersion: String?

    /// ExifTool JSON tag names mapped to Swift property names.
    enum CodingKeys: String, CodingKey {
        case sourceFile = "SourceFile"
        case fileName = "FileName"
        case fileType = "FileType"
        case mimeType = "MIMEType"
        case make = "Make"
        case model = "Model"
        case lensModel = "LensModel"
        case lensID = "LensID"
        case createDate = "CreateDate"
        case dateTimeOriginal = "DateTimeOriginal"
        case customRendered = "CustomRendered"
        case sceneCaptureType = "SceneCaptureType"
        case imageCaptureType = "ImageCaptureType"
        case focalLength = "FocalLength"
        case focalLengthIn35mmFormat = "FocalLengthIn35mmFormat"
        case focalLength35efl = "FocalLength35efl"
        case iso = "ISO"
        case fNumber = "FNumber"
        case exposureTime = "ExposureTime"
        case gpsLatitude = "GPSLatitude"
        case gpsLongitude = "GPSLongitude"
        case gpsAltitude = "GPSAltitude"
        case gpsPosition = "GPSPosition"
        case imageWidth = "ImageWidth"
        case imageHeight = "ImageHeight"
        case megapixels = "Megapixels"
        case productName = "ProductName"
        case relativeAltitude = "RelativeAltitude"
        case absoluteAltitude = "AbsoluteAltitude"
        case gimbalPitchDegree = "GimbalPitchDegree"
        case gimbalYawDegree = "GimbalYawDegree"
        case gimbalRollDegree = "GimbalRollDegree"
        case flightPitchDegree = "FlightPitchDegree"
        case flightYawDegree = "FlightYawDegree"
        case flightRollDegree = "FlightRollDegree"
        case hdrGainMapVersion = "HDRGainMapVersion"
        case hdrGainMapHeadroom = "HDRGainMapHeadroom"
        case auxiliaryImageType = "AuxiliaryImageType"
        case simulatedAperture = "SimulatedAperture"
        case effectStrength = "EffectStrength"
        case depthDataVersion = "DepthDataVersion"
    }

    /// Creates metadata by decoding ExifTool JSON values as optional strings.
    /// - Parameter decoder: The decoder reading an ExifTool JSON object.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceFile = container.lossyString(forKey: .sourceFile)
        fileName = container.lossyString(forKey: .fileName)
        fileType = container.lossyString(forKey: .fileType)
        mimeType = container.lossyString(forKey: .mimeType)
        make = container.lossyString(forKey: .make)
        model = container.lossyString(forKey: .model)
        lensModel = container.lossyString(forKey: .lensModel)
        lensID = container.lossyString(forKey: .lensID)
        createDate = container.lossyString(forKey: .createDate)
        dateTimeOriginal = container.lossyString(forKey: .dateTimeOriginal)
        customRendered = container.lossyString(forKey: .customRendered)
        sceneCaptureType = container.lossyString(forKey: .sceneCaptureType)
        imageCaptureType = container.lossyString(forKey: .imageCaptureType)
        focalLength = container.lossyString(forKey: .focalLength)
        focalLengthIn35mmFormat = container.lossyString(forKey: .focalLengthIn35mmFormat)
        focalLength35efl = container.lossyString(forKey: .focalLength35efl)
        iso = container.lossyString(forKey: .iso)
        fNumber = container.lossyString(forKey: .fNumber)
        exposureTime = container.lossyString(forKey: .exposureTime)
        gpsLatitude = container.lossyString(forKey: .gpsLatitude)
        gpsLongitude = container.lossyString(forKey: .gpsLongitude)
        gpsAltitude = container.lossyString(forKey: .gpsAltitude)
        gpsPosition = container.lossyString(forKey: .gpsPosition)
        imageWidth = container.lossyString(forKey: .imageWidth)
        imageHeight = container.lossyString(forKey: .imageHeight)
        megapixels = container.lossyString(forKey: .megapixels)
        productName = container.lossyString(forKey: .productName)
        relativeAltitude = container.lossyString(forKey: .relativeAltitude)
        absoluteAltitude = container.lossyString(forKey: .absoluteAltitude)
        gimbalPitchDegree = container.lossyString(forKey: .gimbalPitchDegree)
        gimbalYawDegree = container.lossyString(forKey: .gimbalYawDegree)
        gimbalRollDegree = container.lossyString(forKey: .gimbalRollDegree)
        flightPitchDegree = container.lossyString(forKey: .flightPitchDegree)
        flightYawDegree = container.lossyString(forKey: .flightYawDegree)
        flightRollDegree = container.lossyString(forKey: .flightRollDegree)
        hdrGainMapVersion = container.lossyString(forKey: .hdrGainMapVersion)
        hdrGainMapHeadroom = container.lossyString(forKey: .hdrGainMapHeadroom)
        auxiliaryImageType = container.lossyString(forKey: .auxiliaryImageType)
        simulatedAperture = container.lossyString(forKey: .simulatedAperture)
        effectStrength = container.lossyString(forKey: .effectStrength)
        depthDataVersion = container.lossyString(forKey: .depthDataVersion)
    }
}

/// Helpers for decoding ExifTool JSON values that may be strings, numbers, or booleans.
private extension KeyedDecodingContainer {
    /// Decodes a value as a readable optional string.
    /// - Parameter key: The coding key to decode.
    /// - Returns: The decoded string representation, or `nil` when unavailable.
    func lossyString(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }

        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }

        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return String(value)
        }

        return nil
    }
}
