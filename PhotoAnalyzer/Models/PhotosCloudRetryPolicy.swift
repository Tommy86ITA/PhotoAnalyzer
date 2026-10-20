//
//  PhotosCloudRetryPolicy.swift
//  PhotoAnalyzer
//

import Foundation

#if canImport(Photos)
@preconcurrency import Photos
#endif

/// Retry rules for transient PhotoKit and URL-loading failures.
nonisolated enum PhotosCloudRetryPolicy {
    static let maximumAttempts = 3

    static func delayNanoseconds(afterAttempt attempt: Int) -> UInt64 {
        let baseDelay: UInt64 = 500_000_000
        let exponent = UInt64(max(0, min(attempt - 1, 4)))
        return baseDelay << exponent
    }

    static func shouldRetry(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return [
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorDNSLookupFailed,
                NSURLErrorNotConnectedToInternet
            ].contains(nsError.code)
        }

        #if canImport(Photos)
        guard nsError.domain == PHPhotosErrorDomain,
              let code = PHPhotosError.Code(rawValue: nsError.code) else {
            return false
        }
        return code == .networkError || code == .operationInterrupted
        #else
        return false
        #endif
    }
}
