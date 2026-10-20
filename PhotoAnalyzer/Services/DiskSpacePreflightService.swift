//
//  DiskSpacePreflightService.swift
//  PhotoAnalyzer
//

import Foundation

nonisolated struct DiskSpaceRequirement: Equatable, Sendable {
    let estimatedBytes: Int64
    let reserveBytes: Int64

    var requiredAvailableBytes: Int64 {
        estimatedBytes.addingReportingOverflow(reserveBytes).overflow
            ? Int64.max
            : estimatedBytes + reserveBytes
    }
}

nonisolated enum DiskSpacePreflightError: LocalizedError, Equatable {
    case insufficientSpace(requiredBytes: Int64, availableBytes: Int64, location: String)

    var errorDescription: String? {
        switch self {
        case .insufficientSpace(let requiredBytes, let availableBytes, let location):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let required = formatter.string(fromByteCount: requiredBytes)
            let available = formatter.string(fromByteCount: availableBytes)
            return "Not enough free space on \(location). PhotoAnalyzer needs about \(required), but only \(available) is available."
        }
    }
}

/// Checks the capacity macOS makes available for important file-system usage.
nonisolated struct DiskSpacePreflightService: Sendable {
    typealias AvailableCapacityProvider = @Sendable (URL) throws -> Int64?

    private let availableCapacityProvider: AvailableCapacityProvider

    init(availableCapacityProvider: @escaping AvailableCapacityProvider = Self.systemAvailableCapacity) {
        self.availableCapacityProvider = availableCapacityProvider
    }

    func requireAvailableSpace(
        at directoryURL: URL,
        requirement: DiskSpaceRequirement
    ) throws {
        guard let availableBytes = try availableCapacityProvider(directoryURL),
              availableBytes < requirement.requiredAvailableBytes else {
            return
        }

        throw DiskSpacePreflightError.insufficientSpace(
            requiredBytes: requirement.requiredAvailableBytes,
            availableBytes: availableBytes,
            location: directoryURL.path
        )
    }

    private static func systemAvailableCapacity(at directoryURL: URL) throws -> Int64? {
        let values = try directoryURL.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ])
        if let capacity = values.volumeAvailableCapacityForImportantUsage {
            return capacity
        }
        return values.volumeAvailableCapacity.map(Int64.init)
    }
}

/// Conservative estimates used before writing temporary Photos assets and package output.
nonisolated enum AnalysisDiskSpaceEstimator {
    static let temporaryReserveBytes: Int64 = 512 * 1_024 * 1_024
    static let outputReserveBytes: Int64 = 256 * 1_024 * 1_024
    private static let previewBytes: Int64 = 1 * 1_024 * 1_024
    private static let minimumOriginalBytes: Int64 = 8 * 1_024 * 1_024
    private static let outputBytesPerPhoto: Int64 = 3 * 1_024 * 1_024

    static func temporaryBytes(
        pixelWidth: Int,
        pixelHeight: Int,
        usesPreview: Bool
    ) -> Int64 {
        guard !usesPreview else {
            return previewBytes
        }

        let pixels = Int64(max(1, pixelWidth)).multipliedReportingOverflow(by: Int64(max(1, pixelHeight)))
        guard !pixels.overflow else {
            return Int64.max
        }
        let decodedEstimate = pixels.partialValue.multipliedReportingOverflow(by: 4)
        return decodedEstimate.overflow ? Int64.max : max(minimumOriginalBytes, decodedEstimate.partialValue)
    }

    static func outputRequirement(photoCount: Int) -> DiskSpaceRequirement {
        let estimate = Int64(max(1, photoCount)).multipliedReportingOverflow(by: outputBytesPerPhoto)
        return DiskSpaceRequirement(
            estimatedBytes: estimate.overflow ? Int64.max : estimate.partialValue,
            reserveBytes: outputReserveBytes
        )
    }
}
