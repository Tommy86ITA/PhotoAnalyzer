//
//  PhotosLibraryAuthorizationService.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 26/06/2026.
//

import Foundation

#if canImport(Photos)
@preconcurrency import Photos
#endif

/// Requests Photos Library read access for PhotoKit-backed source scopes.
nonisolated struct PhotosLibraryAuthorizationService: Sendable {
    func requestReadAccessIfNeeded() async throws {
        #if canImport(Photos)
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            return
        case .notDetermined:
            let requestedStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard requestedStatus == .authorized || requestedStatus == .limited else {
                throw PhotosLibraryAssetExporterError.unauthorized
            }
        case .denied, .restricted:
            throw PhotosLibraryAssetExporterError.unauthorized
        @unknown default:
            throw PhotosLibraryAssetExporterError.unauthorized
        }
        #else
        throw PhotosLibraryAssetExporterError.photosUnavailable
        #endif
    }
}
