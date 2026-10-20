//
//  SecurityScopedResourceAccess.swift
//  PhotoAnalyzer
//
//  Created by Codex on 20/10/2026.
//

import Foundation

/// Keeps a security-scoped folder URL accessible for as long as the app needs its generated files.
@MainActor
final class SecurityScopedResourceAccess {
    private var resourceURL: URL?
    private var isAccessingResource = false

    func update(to url: URL?) {
        guard resourceURL?.standardizedFileURL != url?.standardizedFileURL else {
            return
        }

        stopAccessing()
        resourceURL = url
        isAccessingResource = url?.startAccessingSecurityScopedResource() ?? false
    }

    deinit {
        if isAccessingResource {
            resourceURL?.stopAccessingSecurityScopedResource()
        }
    }

    private func stopAccessing() {
        if isAccessingResource {
            resourceURL?.stopAccessingSecurityScopedResource()
        }

        resourceURL = nil
        isAccessingResource = false
    }
}
