//
//  FormatterAndProgressTests.swift
//  PhotoAnalyzerTests
//
//  Created by Thomas Amaranto on 19/06/2026.
//

import Testing
@testable import PhotoAnalyzer

struct FormatterAndProgressTests {
    @Test func thumbnailIndexFormatterPadsIndexes() {
        #expect(ThumbnailIndexFormatter.string(from: 1) == "001")
        #expect(ThumbnailIndexFormatter.string(from: 42) == "042")
        #expect(ThumbnailIndexFormatter.string(from: 1000) == "1000")
    }

    @Test func pipelineProgressMapperClampsAndOffsetsProgress() {
        let mapper = PipelineProgressMapper(
            startingUnitCount: 10,
            totalUnitCount: 20,
            allocatedUnitCount: 5,
            phase: .generatingContactSheet
        )

        let progress = mapper.map(
            ProgressSnapshot(
                completedUnitCount: 50,
                totalUnitCount: 100,
                message: "Writing contact sheet..."
            )
        )

        #expect(progress.fractionCompleted == 0.625)
        #expect(progress.message == "Writing contact sheet...")
        #expect(progress.phase == .generatingContactSheet)
    }
}
