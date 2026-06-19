//
//  ContactSheetViewerPresenter.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import AppKit
import Foundation

/// Owns the lifecycle of the dedicated contact sheet viewer window.
@MainActor
final class ContactSheetViewerPresenter {
    private var window: NSWindow?

    func open(pageURLs: [URL], initialPageIndex: Int) {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = ContactSheetViewerWindowFactory.makeWindow(
            pageURLs: pageURLs,
            initialPageIndex: initialPageIndex
        )
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}
