//
//  ExportPhotoMetadata.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import Foundation

/// Rich metadata used only by the AI analysis package export.
nonisolated struct ExportPhotoMetadata: Codable, Sendable {
    let fileName: String?
    let sourceFile: String?
    let fileType: String?
    let fileTypeExtension: String?
    let mimeType: String?
    let fileSize: String?
    let imageWidth: Double?
    let imageHeight: Double?
    let make: String?
    let model: String?
    let productName: String?
    let software: String?
    let createDate: String?
    let dateTimeOriginal: String?
    let lensModel: String?
    let lensID: String?
    let focalLength: Double?
    let focalLengthIn35mmFormat: Double?
    let focalLength35efl: Double?
    let digitalZoomRatio: Double?
    let fov: Double?
    let fNumber: Double?
    let exposureTime: Double?
    let iso: Int?
    let exposureCompensation: Double?
    let flash: String?
    let whiteBalance: String?
    let gpsLatitude: Double?
    let gpsLongitude: Double?
    let gpsAltitude: Double?
    let gpsImgDirection: Double?
    let appleImageCaptureType: String?
    let appleCameraType: String?
    let appleFocusPosition: Double?
    let appleFocusDistanceRange: String?
    let appleAFMeasuredDepth: Double?
    let appleAFConfidence: Double?
    let appleHDRHeadroom: Double?
    let appleHDRGain: Double?
    let appleSignalToNoiseRatio: Double?
    let appleColorTemperature: Double?
    let customRendered: String?
    let compositeImage: String?
    let hdrGainMapVersion: String?
    let hdrGainMapHeadroom: Double?
    let quickTimeAuxiliaryImageType: String?
    let xmpApdiAuxiliaryImageType: String?
    let xmpDepthDataFiltered: String?
    let xmpDepthDataAccuracy: String?
    let xmpDepthDataQuality: String?

    enum CodingKeys: String, CodingKey {
        case fileName = "File:FileName"
        case sourceFile = "SourceFile"
        case fileType = "File:FileType"
        case fileTypeExtension = "File:FileTypeExtension"
        case mimeType = "File:MIMEType"
        case fileSize = "File:FileSize"
        case imageWidth = "Composite:ImageWidth"
        case imageHeight = "Composite:ImageHeight"
        case make = "IFD0:Make"
        case model = "IFD0:Model"
        case software = "IFD0:Software"
        case createDate = "ExifIFD:CreateDate"
        case dateTimeOriginal = "ExifIFD:DateTimeOriginal"
        case lensModel = "ExifIFD:LensModel"
        case focalLength = "ExifIFD:FocalLength"
        case focalLengthIn35mmFormat = "ExifIFD:FocalLengthIn35mmFormat"
        case digitalZoomRatio = "ExifIFD:DigitalZoomRatio"
        case fov = "Composite:FOV"
        case fNumber = "ExifIFD:FNumber"
        case exposureTime = "ExifIFD:ExposureTime"
        case iso = "ExifIFD:ISO"
        case exposureCompensation = "ExifIFD:ExposureCompensation"
        case flash = "ExifIFD:Flash"
        case whiteBalance = "ExifIFD:WhiteBalance"
        case gpsLatitude = "GPS:GPSLatitude"
        case gpsLongitude = "GPS:GPSLongitude"
        case gpsAltitude = "GPS:GPSAltitude"
        case gpsImgDirection = "GPS:GPSImgDirection"
        case appleImageCaptureType = "Apple:ImageCaptureType"
        case appleCameraType = "Apple:CameraType"
        case appleFocusPosition = "Apple:FocusPosition"
        case appleFocusDistanceRange = "Apple:FocusDistanceRange"
        case appleAFMeasuredDepth = "Apple:AFMeasuredDepth"
        case appleAFConfidence = "Apple:AFConfidence"
        case appleHDRHeadroom = "Apple:HDRHeadroom"
        case appleHDRGain = "Apple:HDRGain"
        case appleSignalToNoiseRatio = "Apple:SignalToNoiseRatio"
        case appleColorTemperature = "Apple:ColorTemperature"
        case customRendered = "ExifIFD:CustomRendered"
        case compositeImage = "ExifIFD:CompositeImage"
        case quickTimeAuxiliaryImageType = "QuickTime:AuxiliaryImageType"
        case xmpApdiAuxiliaryImageType = "XMP-apdi:AuxiliaryImageType"
        case xmpDepthDataFiltered = "XMP-depthData:Filtered"
        case xmpDepthDataAccuracy = "XMP-depthData:Accuracy"
        case xmpDepthDataQuality = "XMP-depthData:Quality"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        fileName = container.lossyString(forKeys: ["File:FileName", "FileName"])
        sourceFile = container.lossyString(forKeys: ["SourceFile"])
        fileType = container.lossyString(forKeys: ["File:FileType", "FileType"])
        fileTypeExtension = container.lossyString(forKeys: ["File:FileTypeExtension", "FileTypeExtension"])
        mimeType = container.lossyString(forKeys: ["File:MIMEType", "MIMEType"])
        fileSize = container.lossyString(forKeys: ["File:FileSize", "FileSize"])
        imageWidth = container.lossyDouble(forKeys: ["Composite:ImageWidth", "File:ImageWidth", "ExifIFD:ImageWidth", "ImageWidth"])
        imageHeight = container.lossyDouble(forKeys: ["Composite:ImageHeight", "File:ImageHeight", "ExifIFD:ImageHeight", "ImageHeight"])
        make = container.lossyString(forKeys: ["IFD0:Make", "QuickTime:Make", "Make"])
        model = container.lossyString(forKeys: ["IFD0:Model", "QuickTime:Model", "Model"])
        productName = container.lossyString(forKeys: ["XMP-drone-dji:ProductName", "MakerNotes:ProductName", "ProductName"])
        software = container.lossyString(forKeys: ["IFD0:Software", "QuickTime:Software", "Software"])
        createDate = container.lossyString(forKeys: ["ExifIFD:CreateDate", "QuickTime:CreateDate", "CreateDate"])
        dateTimeOriginal = container.lossyString(forKeys: ["ExifIFD:DateTimeOriginal", "DateTimeOriginal"])
        lensModel = container.lossyString(forKeys: ["ExifIFD:LensModel", "Composite:LensID", "LensModel"])
        lensID = container.lossyString(forKeys: ["Composite:LensID", "MakerNotes:LensID", "LensID"])
        focalLength = container.lossyDouble(forKeys: ["ExifIFD:FocalLength", "FocalLength"])
        focalLengthIn35mmFormat = container.lossyDouble(forKeys: ["ExifIFD:FocalLengthIn35mmFormat", "Composite:FocalLength35efl", "FocalLengthIn35mmFormat"])
        focalLength35efl = container.lossyDouble(forKeys: ["Composite:FocalLength35efl", "FocalLength35efl"])
        digitalZoomRatio = container.lossyDouble(forKeys: ["ExifIFD:DigitalZoomRatio", "DigitalZoomRatio"])
        fov = container.lossyDouble(forKeys: ["Composite:FOV", "FOV"])
        fNumber = container.lossyDouble(forKeys: ["ExifIFD:FNumber", "FNumber"])
        exposureTime = container.lossyExposureTime(forKeys: ["ExifIFD:ExposureTime", "ExposureTime"])
        iso = container.lossyInt(forKeys: ["ExifIFD:ISO", "ISO"])
        exposureCompensation = container.lossyDouble(forKeys: ["ExifIFD:ExposureCompensation", "ExposureCompensation"])
        flash = container.lossyString(forKeys: ["ExifIFD:Flash", "Flash"])
        whiteBalance = container.lossyString(forKeys: ["ExifIFD:WhiteBalance", "WhiteBalance"])
        gpsLatitude = container.lossyGPSCoordinate(forKeys: ["GPS:GPSLatitude", "GPSLatitude"])
        gpsLongitude = container.lossyGPSCoordinate(forKeys: ["GPS:GPSLongitude", "GPSLongitude"])
        gpsAltitude = container.lossyGPSAltitude(forKeys: ["GPS:GPSAltitude", "GPSAltitude"])
        gpsImgDirection = container.lossyDouble(forKeys: ["GPS:GPSImgDirection", "GPSImgDirection"])
        appleImageCaptureType = container.lossyString(forKeys: ["Apple:ImageCaptureType", "ImageCaptureType"])
        appleCameraType = container.lossyString(forKeys: ["Apple:CameraType", "CameraType"])
        appleFocusPosition = container.lossyDouble(forKeys: ["Apple:FocusPosition", "FocusPosition"])
        appleFocusDistanceRange = container.lossyString(forKeys: ["Apple:FocusDistanceRange", "FocusDistanceRange"])
        appleAFMeasuredDepth = container.lossyDouble(forKeys: ["Apple:AFMeasuredDepth", "AFMeasuredDepth"])
        appleAFConfidence = container.lossyDouble(forKeys: ["Apple:AFConfidence", "AFConfidence"])
        appleHDRHeadroom = container.lossyDouble(forKeys: ["Apple:HDRHeadroom", "HDRHeadroom", "Apple:HDRGainMapHeadroom", "HDRGainMapHeadroom"])
        appleHDRGain = container.lossyDouble(forKeys: ["Apple:HDRGain", "HDRGain"])
        appleSignalToNoiseRatio = container.lossyDouble(forKeys: ["Apple:SignalToNoiseRatio", "SignalToNoiseRatio"])
        appleColorTemperature = container.lossyDouble(forKeys: ["Apple:ColorTemperature", "ColorTemperature"])
        customRendered = container.lossyString(forKeys: ["ExifIFD:CustomRendered", "CustomRendered"])
        compositeImage = container.lossyString(forKeys: ["ExifIFD:CompositeImage", "CompositeImage"])
        hdrGainMapVersion = container.lossyString(forKeys: ["Apple:HDRGainMapVersion", "HDRGainMapVersion"])
        hdrGainMapHeadroom = container.lossyDouble(forKeys: ["Apple:HDRGainMapHeadroom", "HDRGainMapHeadroom"])
        quickTimeAuxiliaryImageType = container.lossyString(forKeys: ["QuickTime:AuxiliaryImageType", "AuxiliaryImageType"])
        xmpApdiAuxiliaryImageType = container.lossyString(forKeys: ["XMP-apdi:AuxiliaryImageType"])
        xmpDepthDataFiltered = container.lossyString(forKeys: ["XMP-depthData:Filtered"])
        xmpDepthDataAccuracy = container.lossyString(forKeys: ["XMP-depthData:Accuracy"])
        xmpDepthDataQuality = container.lossyString(forKeys: ["XMP-depthData:Quality"])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(fileName, forKey: .fileName)
        try container.encodeIfPresent(sourceFile, forKey: .sourceFile)
        try container.encodeIfPresent(fileType, forKey: .fileType)
        try container.encodeIfPresent(fileTypeExtension, forKey: .fileTypeExtension)
        try container.encodeIfPresent(mimeType, forKey: .mimeType)
        try container.encodeIfPresent(fileSize, forKey: .fileSize)
        try container.encodeIfPresent(imageWidth, forKey: .imageWidth)
        try container.encodeIfPresent(imageHeight, forKey: .imageHeight)
        try container.encodeIfPresent(make, forKey: .make)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(software, forKey: .software)
        try container.encodeIfPresent(createDate, forKey: .createDate)
        try container.encodeIfPresent(dateTimeOriginal, forKey: .dateTimeOriginal)
        try container.encodeIfPresent(lensModel, forKey: .lensModel)
        try container.encodeIfPresent(focalLength, forKey: .focalLength)
        try container.encodeIfPresent(focalLengthIn35mmFormat, forKey: .focalLengthIn35mmFormat)
        try container.encodeIfPresent(digitalZoomRatio, forKey: .digitalZoomRatio)
        try container.encodeIfPresent(fov, forKey: .fov)
        try container.encodeIfPresent(fNumber, forKey: .fNumber)
        try container.encodeIfPresent(exposureTime, forKey: .exposureTime)
        try container.encodeIfPresent(iso, forKey: .iso)
        try container.encodeIfPresent(exposureCompensation, forKey: .exposureCompensation)
        try container.encodeIfPresent(flash, forKey: .flash)
        try container.encodeIfPresent(whiteBalance, forKey: .whiteBalance)
        try container.encodeIfPresent(gpsLatitude, forKey: .gpsLatitude)
        try container.encodeIfPresent(gpsLongitude, forKey: .gpsLongitude)
        try container.encodeIfPresent(gpsAltitude, forKey: .gpsAltitude)
        try container.encodeIfPresent(gpsImgDirection, forKey: .gpsImgDirection)
        try container.encodeIfPresent(appleImageCaptureType, forKey: .appleImageCaptureType)
        try container.encodeIfPresent(appleCameraType, forKey: .appleCameraType)
        try container.encodeIfPresent(appleFocusPosition, forKey: .appleFocusPosition)
        try container.encodeIfPresent(appleFocusDistanceRange, forKey: .appleFocusDistanceRange)
        try container.encodeIfPresent(appleAFMeasuredDepth, forKey: .appleAFMeasuredDepth)
        try container.encodeIfPresent(appleAFConfidence, forKey: .appleAFConfidence)
        try container.encodeIfPresent(appleHDRHeadroom, forKey: .appleHDRHeadroom)
        try container.encodeIfPresent(appleHDRGain, forKey: .appleHDRGain)
        try container.encodeIfPresent(appleSignalToNoiseRatio, forKey: .appleSignalToNoiseRatio)
        try container.encodeIfPresent(appleColorTemperature, forKey: .appleColorTemperature)
        try container.encodeIfPresent(customRendered, forKey: .customRendered)
        try container.encodeIfPresent(compositeImage, forKey: .compositeImage)
        try container.encodeIfPresent(quickTimeAuxiliaryImageType, forKey: .quickTimeAuxiliaryImageType)
        try container.encodeIfPresent(xmpApdiAuxiliaryImageType, forKey: .xmpApdiAuxiliaryImageType)
        try container.encodeIfPresent(xmpDepthDataFiltered, forKey: .xmpDepthDataFiltered)
        try container.encodeIfPresent(xmpDepthDataAccuracy, forKey: .xmpDepthDataAccuracy)
        try container.encodeIfPresent(xmpDepthDataQuality, forKey: .xmpDepthDataQuality)
    }
}

/// Export wrapper that adds the contact sheet index to ExifTool metadata.
nonisolated struct IndexedExportPhotoMetadata: Encodable, Sendable {
    let metadata: ExportPhotoMetadata
    let thumbnailIndex: String?
    let contactSheetPage: Int?
    let contactSheetFile: String?
    let displayInfo: SourceFileDisplayInfo?

    enum CodingKeys: String, CodingKey {
        case thumbnailIndex = "ThumbnailIndex"
        case contactSheetPage = "ContactSheetPage"
        case contactSheetFile = "ContactSheetFile"
        case displayFileName = "File:FileName"
        case displaySourceFile = "SourceFile"
    }

    func encode(to encoder: Encoder) throws {
        try metadata.encode(to: encoder)

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(displayInfo?.fileName, forKey: .displayFileName)
        try container.encodeIfPresent(displayInfo?.sourceFile, forKey: .displaySourceFile)
        try container.encodeIfPresent(thumbnailIndex, forKey: .thumbnailIndex)
        try container.encodeIfPresent(contactSheetPage, forKey: .contactSheetPage)
        try container.encodeIfPresent(contactSheetFile, forKey: .contactSheetFile)
    }
}

nonisolated private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where Key == DynamicCodingKey {
    nonisolated func lossyString(forKeys keys: [String]) -> String? {
        for key in keys {
            guard let codingKey = DynamicCodingKey(stringValue: key) else {
                continue
            }

            if let value = try? decodeIfPresent(String.self, forKey: codingKey) {
                return value
            }

            if let value = try? decodeIfPresent(Int.self, forKey: codingKey) {
                return String(value)
            }

            if let value = try? decodeIfPresent(Double.self, forKey: codingKey) {
                return String(value)
            }

            if let value = try? decodeIfPresent(Bool.self, forKey: codingKey) {
                return String(value)
            }
        }

        return nil
    }

    nonisolated func lossyDouble(forKeys keys: [String]) -> Double? {
        ExifToolValueParser.double(from: lossyString(forKeys: keys))
    }

    nonisolated func lossyInt(forKeys keys: [String]) -> Int? {
        ExifToolValueParser.int(from: lossyString(forKeys: keys))
    }

    nonisolated func lossyExposureTime(forKeys keys: [String]) -> Double? {
        ExifToolValueParser.exposureTime(from: lossyString(forKeys: keys))
    }

    nonisolated func lossyGPSCoordinate(forKeys keys: [String]) -> Double? {
        ExifToolValueParser.gpsCoordinate(from: lossyString(forKeys: keys))
    }

    nonisolated func lossyGPSAltitude(forKeys keys: [String]) -> Double? {
        ExifToolValueParser.gpsAltitude(from: lossyString(forKeys: keys))
    }
}
