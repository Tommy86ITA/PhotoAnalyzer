//
//  DatasetQualityReportService.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 28/06/2026.
//

import Foundation

/// Builds dataset quality summaries from analyzed photo metadata.
nonisolated struct DatasetQualityReportService {
    private let maximumSampleCount = 100

    func makeReport(
        photos: [PhotoInfo],
        exportMetadata: [ExportPhotoMetadata],
        sourceFileURLs: [URL],
        displayInfoByFileURL: [URL: SourceFileDisplayInfo],
        generatedAt: Date = Date()
    ) -> DatasetQualityReport {
        var missingCaptureDate = 0
        var missingGpsLocation = 0
        var missingCameraModel = 0
        var missingLensModel = 0
        var missingExposureSettings = 0
        var issueSamples: [DatasetQualityIssueSample] = []

        for (index, photo) in photos.enumerated() {
            var issues: [String] = []

            if photo.captureDate == nil {
                missingCaptureDate += 1
                issues.append("missing_capture_date")
            }

            if photo.latitude == nil || photo.longitude == nil {
                missingGpsLocation += 1
                issues.append("missing_gps_location")
            }

            if isBlank(photo.cameraModel) {
                missingCameraModel += 1
                issues.append("missing_camera_model")
            }

            if isBlank(photo.lensModel) {
                missingLensModel += 1
                issues.append("missing_lens_model")
            }

            if photo.iso == nil || photo.aperture == nil || photo.exposureTime == nil || photo.focalLength == nil {
                missingExposureSettings += 1
                issues.append("missing_exposure_settings")
            }

            if !issues.isEmpty && issueSamples.count < maximumSampleCount {
                issueSamples.append(
                    sample(
                        for: photo,
                        at: index,
                        issues: issues,
                        sourceFileURLs: sourceFileURLs,
                        displayInfoByFileURL: displayInfoByFileURL
                    )
                )
            }
        }

        return DatasetQualityReport(
            generatedAt: timestamp(from: generatedAt),
            analyzedPhotoCount: photos.count,
            metadataRecordCount: exportMetadata.count,
            issueCounts: DatasetQualityIssueCounts(
                missingCaptureDate: missingCaptureDate,
                missingGpsLocation: missingGpsLocation,
                missingCameraModel: missingCameraModel,
                missingLensModel: missingLensModel,
                missingExposureSettings: missingExposureSettings
            ),
            issueSamples: issueSamples
        )
    }

    private func sample(
        for photo: PhotoInfo,
        at index: Int,
        issues: [String],
        sourceFileURLs: [URL],
        displayInfoByFileURL: [URL: SourceFileDisplayInfo]
    ) -> DatasetQualityIssueSample {
        let sourceFileURL = index < sourceFileURLs.count ? sourceFileURLs[index] : nil
        let displayInfo = sourceFileURL.flatMap { displayInfoByFileURL[$0] }

        return DatasetQualityIssueSample(
            thumbnailIndex: ThumbnailIndexFormatter.string(from: index + 1),
            fileName: displayInfo?.fileName ?? photo.fileName,
            sourceFile: displayInfo?.sourceFile ?? sourceFileURL?.path,
            issues: issues
        )
    }

    private func isBlank(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    private func timestamp(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
