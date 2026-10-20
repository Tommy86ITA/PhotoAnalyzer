//
//  DiskSpaceAndRetryPolicyTests.swift
//  PhotoAnalyzerTests
//

import Foundation
import Testing
@testable import PhotoAnalyzer

struct DiskSpaceAndRetryPolicyTests {
    @Test func diskPreflightRejectsInsufficientCapacity() {
        let service = DiskSpacePreflightService { _ in 100 }

        #expect(throws: DiskSpacePreflightError.self) {
            try service.requireAvailableSpace(
                at: URL(fileURLWithPath: "/tmp"),
                requirement: DiskSpaceRequirement(
                    estimatedBytes: 80,
                    reserveBytes: 30
                )
            )
        }
    }

    @Test func diskPreflightAllowsEnoughCapacity() throws {
        let service = DiskSpacePreflightService { _ in 1_000 }

        try service.requireAvailableSpace(
            at: URL(fileURLWithPath: "/tmp"),
            requirement: DiskSpaceRequirement(
                estimatedBytes: 80,
                reserveBytes: 30
            )
        )
    }

    @Test func cachedPreviewNeedsLessTemporarySpaceThanOriginal() {
        let preview = AnalysisDiskSpaceEstimator.temporaryBytes(
            pixelWidth: 6_000,
            pixelHeight: 4_000,
            usesPreview: true
        )
        let original = AnalysisDiskSpaceEstimator.temporaryBytes(
            pixelWidth: 6_000,
            pixelHeight: 4_000,
            usesPreview: false
        )

        #expect(preview < original)
    }

    @Test func cloudRetryPolicyRetriesOnlyTransientURLFailures() {
        let transientError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost
        )
        let permanentError = CocoaError(.fileReadNoPermission)

        #expect(PhotosCloudRetryPolicy.shouldRetry(transientError))
        #expect(!PhotosCloudRetryPolicy.shouldRetry(permanentError))
        #expect(PhotosCloudRetryPolicy.maximumAttempts == 3)
        #expect(
            PhotosCloudRetryPolicy.delayNanoseconds(afterAttempt: 2)
                > PhotosCloudRetryPolicy.delayNanoseconds(afterAttempt: 1)
        )
    }
}
