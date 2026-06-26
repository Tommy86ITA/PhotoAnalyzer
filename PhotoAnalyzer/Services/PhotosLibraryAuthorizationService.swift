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
    #if canImport(Photos)
    private static let coordinator = PhotosLibraryAuthorizationCoordinator()
    #endif

    func requestReadAccessIfNeeded() async throws {
        #if canImport(Photos)
        try await Self.coordinator.requestReadAccessIfNeeded()
        #else
        throw PhotosLibraryAssetExporterError.photosUnavailable
        #endif
    }
}

#if canImport(Photos)
private actor PhotosLibraryAuthorizationCoordinator {
    private var requestTask: Task<PHAuthorizationStatus, Never>?

    func requestReadAccessIfNeeded() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            return
        case .notDetermined:
            let requestedStatus = await authorizationRequest().value
            guard requestedStatus == .authorized || requestedStatus == .limited else {
                throw PhotosLibraryAssetExporterError.unauthorized
            }
        case .denied, .restricted:
            throw PhotosLibraryAssetExporterError.unauthorized
        @unknown default:
            throw PhotosLibraryAssetExporterError.unauthorized
        }
    }

    private func authorizationRequest() -> Task<PHAuthorizationStatus, Never> {
        if let requestTask {
            return requestTask
        }

        let task = Task {
            await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        requestTask = task
        return task
    }
}
#endif
