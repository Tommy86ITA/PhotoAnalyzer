//
//  ContactSheetViewerView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 17/06/2026.
//

import AppKit
import SwiftUI

/// Dedicated viewer for the generated contact sheet.
struct ContactSheetViewerView: View {
    private enum Layout {
        static let minimumWidth: CGFloat = 900
        static let minimumHeight: CGFloat = 650
        static let toolbarPadding: CGFloat = 16
        static let zoomSliderWidth: CGFloat = 180
    }

    private enum Zoom {
        static let minimum = 0.05
        static let maximum = 3.0
        static let step = 0.1
    }

    let pageURLs: [URL]
    let initialPageIndex: Int
    let close: () -> Void

    @State private var zoom = 1.0
    @State private var currentPageIndex: Int
    @State private var pendingCommand: ContactSheetViewerCommand?

    init(
        pageURLs: [URL],
        initialPageIndex: Int,
        close: @escaping () -> Void
    ) {
        self.pageURLs = pageURLs
        self.initialPageIndex = initialPageIndex
        self.close = close
        _currentPageIndex = State(initialValue: min(max(0, initialPageIndex), max(0, pageURLs.count - 1)))
    }

    var body: some View {
        VStack(spacing: 0) {
            ContactSheetViewerToolbar(
                pageCount: pageURLs.count,
                currentPageIndex: currentPageIndex,
                zoom: Binding(
                    get: { zoom },
                    set: { zoom = clampedZoom($0) }
                ),
                minimumZoom: Zoom.minimum,
                maximumZoom: Zoom.maximum,
                zoomSliderWidth: Layout.zoomSliderWidth,
                showPreviousPage: showPreviousPage,
                showNextPage: showNextPage,
                zoomOut: zoomOut,
                zoomIn: zoomIn,
                fitWidth: { sendCommand(.fitWidth) },
                fitWindow: { sendCommand(.fitWindow) },
                actualSize: { sendCommand(.actualSize) },
                close: close
            )
            .padding(Layout.toolbarPadding)

            Divider()

            if let currentImage {
                ContactSheetScrollImageView(
                    image: currentImage,
                    zoom: $zoom,
                    pendingCommand: $pendingCommand,
                    minimumZoom: Zoom.minimum,
                    maximumZoom: Zoom.maximum,
                    showPreviousPage: showPreviousPage,
                    showNextPage: showNextPage
                )
            } else {
                ContentUnavailableView(
                    "Preview unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The selected contact sheet page could not be loaded.")
                )
            }
        }
        .frame(minWidth: Layout.minimumWidth, minHeight: Layout.minimumHeight)
        .onAppear {
            sendCommand(.fitWidth)
        }
        .onChange(of: currentPageIndex) { _, _ in
            sendCommand(.fitWidth)
        }
    }

    private var currentImage: NSImage? {
        guard pageURLs.indices.contains(currentPageIndex) else {
            return nil
        }

        return NSImage(contentsOf: pageURLs[currentPageIndex])
    }

    private func showPreviousPage() {
        currentPageIndex = max(0, currentPageIndex - 1)
    }

    private func showNextPage() {
        currentPageIndex = min(pageURLs.count - 1, currentPageIndex + 1)
    }

    private func zoomIn() {
        zoom = clampedZoom(zoom + Zoom.step)
    }

    private func zoomOut() {
        zoom = clampedZoom(zoom - Zoom.step)
    }

    private func clampedZoom(_ value: Double) -> Double {
        min(Zoom.maximum, max(Zoom.minimum, value))
    }

    private func sendCommand(_ action: ContactSheetViewerCommand.Action) {
        pendingCommand = ContactSheetViewerCommand(action: action)
    }
}
