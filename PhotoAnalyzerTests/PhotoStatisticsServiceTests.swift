//
//  PhotoStatisticsServiceTests.swift
//  PhotoAnalyzerTests
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Foundation
import Testing
@testable import PhotoAnalyzer

struct PhotoStatisticsServiceTests {
    @Test func buildStatisticsAggregatesCoreDistributions() {
        let photos = [
            PhotoInfo(
                fileName: "one.jpg",
                captureDate: nil,
                cameraMake: "Canon",
                cameraModel: "Canon R5",
                lensModel: "RF 50mm",
                focalLength: 50,
                focalLength35mmEquivalent: 50,
                iso: 100,
                aperture: 1.8,
                exposureTime: 1.0 / 125.0,
                latitude: nil,
                longitude: nil,
                photoType: .standard
            ),
            PhotoInfo(
                fileName: "two.jpg",
                captureDate: nil,
                cameraMake: "Canon",
                cameraModel: "Canon R5",
                lensModel: "RF 50mm",
                focalLength: 85,
                focalLength35mmEquivalent: 85,
                iso: 200,
                aperture: 2.8,
                exposureTime: 2,
                latitude: nil,
                longitude: nil,
                photoType: .panorama
            )
        ]

        let statistics = PhotoStatisticsService().buildStatistics(from: photos)

        #expect(statistics.totalPhotos == 2)
        #expect(statistics.photosByType[.standard] == 1)
        #expect(statistics.photosByType[.panorama] == 1)
        #expect(statistics.photosByCamera["Canon R5"] == 2)
        #expect(statistics.lensDistribution["RF 50mm"] == 2)
        #expect(statistics.isoDistribution[100] == 1)
        #expect(statistics.isoDistribution[200] == 1)
        #expect(statistics.focalLength35mmDistribution[50] == 1)
        #expect(statistics.focalLength35mmDistribution[85] == 1)
        #expect(statistics.averageISO == 150)
        #expect(statistics.averageFocalLength35mmEquivalent == 67.5)
        #expect(statistics.apertureDistribution["f/1.8"] == 1)
        #expect(statistics.shutterSpeedDistribution["1/125"] == 1)
        #expect(statistics.shutterSpeedDistribution["2 s"] == 1)
    }
}
