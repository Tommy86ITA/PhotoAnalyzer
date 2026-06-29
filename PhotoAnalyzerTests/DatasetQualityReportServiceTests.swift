//
//  DatasetQualityReportServiceTests.swift
//  PhotoAnalyzerTests
//
//  Created by Thomas Amaranto on 29/06/2026.
//

import Foundation
import Testing
@testable import PhotoAnalyzer

struct DatasetQualityReportServiceTests {
    @Test func makeReportCountsMissingMetadataAndUsesDisplayInfoSamples() {
        let sourceURL = URL(fileURLWithPath: "/tmp/materialized-one.jpg")
        let photos = [
            PhotoInfo(
                fileName: "materialized-one.jpg",
                captureDate: nil,
                cameraMake: nil,
                cameraModel: "   ",
                lensModel: nil,
                focalLength: nil,
                focalLength35mmEquivalent: nil,
                iso: nil,
                aperture: nil,
                exposureTime: nil,
                latitude: nil,
                longitude: 12,
                photoType: .standard
            ),
            PhotoInfo(
                fileName: "complete.jpg",
                captureDate: Date(timeIntervalSince1970: 100),
                cameraMake: "Canon",
                cameraModel: "Canon R5",
                lensModel: "RF 50mm",
                focalLength: 50,
                focalLength35mmEquivalent: 50,
                iso: 100,
                aperture: 1.8,
                exposureTime: 1.0 / 125.0,
                latitude: 45,
                longitude: 9,
                photoType: .standard
            )
        ]

        let report = DatasetQualityReportService().makeReport(
            photos: photos,
            exportMetadata: [],
            sourceFileURLs: [sourceURL],
            displayInfoByFileURL: [
                sourceURL: SourceFileDisplayInfo(
                    fileName: "IMG_0001.HEIC",
                    sourceFile: "photos://asset/local-id-1"
                )
            ],
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(report.generatedAt == "1970-01-01T00:00:00Z")
        #expect(report.analyzedPhotoCount == 2)
        #expect(report.metadataRecordCount == 0)
        #expect(report.issueCounts.missingCaptureDate == 1)
        #expect(report.issueCounts.missingGpsLocation == 1)
        #expect(report.issueCounts.missingCameraModel == 1)
        #expect(report.issueCounts.missingLensModel == 1)
        #expect(report.issueCounts.missingExposureSettings == 1)

        let sample = report.issueSamples.first
        #expect(sample?.thumbnailIndex == "001")
        #expect(sample?.fileName == "IMG_0001.HEIC")
        #expect(sample?.sourceFile == "photos://asset/local-id-1")
        #expect(sample?.issues == [
            "missing_capture_date",
            "missing_gps_location",
            "missing_camera_model",
            "missing_lens_model",
            "missing_exposure_settings"
        ])
    }

    @Test func makeReportCapsIssueSamplesAtOneHundred() {
        let photos = (0..<125).map { index in
            PhotoInfo(
                fileName: "missing-\(index).jpg",
                captureDate: nil,
                cameraMake: nil,
                cameraModel: nil,
                lensModel: nil,
                focalLength: nil,
                focalLength35mmEquivalent: nil,
                iso: nil,
                aperture: nil,
                exposureTime: nil,
                latitude: nil,
                longitude: nil,
                photoType: .standard
            )
        }

        let report = DatasetQualityReportService().makeReport(
            photos: photos,
            exportMetadata: [],
            sourceFileURLs: [],
            displayInfoByFileURL: [:],
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(report.issueCounts.missingCaptureDate == 125)
        #expect(report.issueSamples.count == 100)
        #expect(report.issueSamples.first?.thumbnailIndex == "001")
        #expect(report.issueSamples.last?.thumbnailIndex == "100")
    }
}
