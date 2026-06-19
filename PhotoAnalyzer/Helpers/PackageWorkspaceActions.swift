//
//  PackageWorkspaceActions.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import AppKit
import Foundation

/// Opens generated package artifacts in Finder.
enum PackageWorkspaceActions {
    static func openPackage(at packageURL: URL) {
        NSWorkspace.shared.open(packageURL)
    }

    static func revealArchive(forPackageAt packageURL: URL) {
        let archiveURL = AIAnalysisPackagePaths(packageURL: packageURL).archiveURL
        NSWorkspace.shared.activateFileViewerSelecting([archiveURL])
    }
}
