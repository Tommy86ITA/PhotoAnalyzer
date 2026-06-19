//
//  ParsingTests.swift
//  PhotoAnalyzerTests
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Testing
@testable import PhotoAnalyzer

struct ParsingTests {
    @Test func exifToolValueParserExtractsNumbersAndExposureTimes() {
        #expect(ExifToolValueParser.double(from: "106 mm") == 106)
        #expect(ExifToolValueParser.double(from: "-12.5 m") == -12.5)
        #expect(ExifToolValueParser.int(from: "ISO 400") == 400)
        #expect(ExifToolValueParser.exposureTime(from: "1/250") == 0.004)
        #expect(ExifToolValueParser.exposureTime(from: "2 s") == 2)
        #expect(ExifToolValueParser.double(from: nil) == nil)
    }

    @Test func gpsValueParserConvertsCoordinatesAndAltitude() throws {
        let latitude = try #require(GpsValueParser.parseCoordinate(#"39 deg 18' 20.01" N"#))
        let longitude = try #require(GpsValueParser.parseCoordinate(#"76 deg 36' 15.00" W"#))

        #expect(abs(latitude - 39.3055583333) < 0.000001)
        #expect(abs(longitude - -76.6041666667) < 0.000001)
        #expect(GpsValueParser.parseAltitude("138.4 m Above Sea Level") == 138.4)
        #expect(GpsValueParser.parseAltitude("12 m Below Sea Level") == -12)
        #expect(GpsValueParser.parseCoordinate("not a coordinate") == nil)
    }
}
