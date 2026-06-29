//
//  PhotoInfoMapperTests.swift
//  PhotoAnalyzerTests
//
//  Created by Thomas Amaranto on 29/06/2026.
//

import Foundation
import Testing
@testable import PhotoAnalyzer

struct PhotoInfoMapperTests {
    @Test func mapsGroupedMetadataIntoPhotoInfo() throws {
        let metadata = try metadata(from: """
        {
          "File:FileName": "mapped.jpg",
          "IFD0:Make": "Pentax",
          "IFD0:Model": "K-50",
          "ExifIFD:DateTimeOriginal": "2024:05:17 10:11:12",
          "ExifIFD:LensModel": "HD PENTAX-DA 55-300mm",
          "ExifIFD:FocalLength": "82 mm",
          "ExifIFD:FocalLengthIn35mmFormat": "123 mm",
          "ExifIFD:ISO": "400",
          "ExifIFD:FNumber": "6.3",
          "ExifIFD:ExposureTime": "1/250",
          "GPS:GPSLatitude": "39 deg 18' 20.01\\" N",
          "GPS:GPSLongitude": "76 deg 36' 15.00\\" W",
          "ExifIFD:CustomRendered": "Portrait"
        }
        """)

        let photo = PhotoInfoMapper().photoInfo(
            from: metadata,
            fallbackFileURL: URL(fileURLWithPath: "/tmp/fallback.jpg")
        )

        #expect(photo.fileName == "mapped.jpg")
        #expect(photo.cameraMake == "Pentax")
        #expect(photo.cameraModel == "K-50")
        #expect(photo.lensModel == "HD PENTAX-DA 55-300mm")
        #expect(photo.focalLength == 82)
        #expect(photo.focalLength35mmEquivalent == 123)
        #expect(photo.iso == 400)
        #expect(photo.aperture == 6.3)
        #expect(photo.exposureTime == 0.004)
        #expect(abs((photo.latitude ?? 0) - 39.3055583333) < 0.000001)
        #expect(abs((photo.longitude ?? 0) - -76.6041666667) < 0.000001)
        #expect(photo.photoType == .portrait)
        #expect(photo.captureDate != nil)
    }

    @Test func usesFallbacksAndDetectsHDRMetadata() throws {
        let metadata = try metadata(from: """
        {
          "XMP-drone-dji:ProductName": "DJI Mini",
          "Composite:LensID": "Built-in Lens",
          "Composite:FocalLength35efl": "24 mm",
          "QuickTime:AuxiliaryImageType": "urn:com:apple:photo:2020:aux:hdrgainmap"
        }
        """)

        let photo = PhotoInfoMapper().photoInfo(
            from: metadata,
            fallbackFileURL: URL(fileURLWithPath: "/tmp/FallbackName.heic")
        )

        #expect(photo.fileName == "FallbackName.heic")
        #expect(photo.cameraModel == "DJI Mini")
        #expect(photo.lensModel == "Built-in Lens")
        #expect(photo.focalLength35mmEquivalent == 24)
        #expect(photo.photoType == .hdr)
    }

    private func metadata(from json: String) throws -> ExportPhotoMetadata {
        try JSONDecoder().decode(ExportPhotoMetadata.self, from: Data(json.utf8))
    }
}
