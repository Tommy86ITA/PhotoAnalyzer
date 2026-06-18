//
//  ContactSheetViewerWindowFactory.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import AppKit
import SwiftUI

/// Builds the dedicated contact sheet viewer window.
enum ContactSheetViewerWindowFactory {
    private enum Layout {
        static let width: CGFloat = 1000
        static let height: CGFloat = 720
        static let minimumWidth: CGFloat = 760
        static let minimumHeight: CGFloat = 520
    }

    static func makeWindow(pageURLs: [URL], initialPageIndex: Int) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Layout.width,
                height: Layout.height
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Contact Sheet"
        window.minSize = NSSize(width: Layout.minimumWidth, height: Layout.minimumHeight)
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: ContactSheetViewerView(
                pageURLs: pageURLs,
                initialPageIndex: initialPageIndex
            ) { [weak window] in
                window?.close()
            }
        )
        window.center()

        return window
    }
}
