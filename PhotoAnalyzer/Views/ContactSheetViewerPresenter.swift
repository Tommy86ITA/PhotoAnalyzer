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
    private var closeObserver: WindowCloseObserver?

    func open(pageURLs: [URL], initialPageIndex: Int) {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = ContactSheetViewerWindowFactory.makeWindow(
            pageURLs: pageURLs,
            initialPageIndex: initialPageIndex
        )
        let closeObserver = WindowCloseObserver { [weak self] in
            self?.window = nil
            self?.closeObserver = nil
        }
        window.delegate = closeObserver
        window.makeKeyAndOrderFront(nil)
        self.window = window
        self.closeObserver = closeObserver
    }

    private final class WindowCloseObserver: NSObject, NSWindowDelegate {
        private let onClose: () -> Void

        init(onClose: @escaping () -> Void) {
            self.onClose = onClose
        }

        func windowWillClose(_ notification: Notification) {
            onClose()
        }
    }
}
