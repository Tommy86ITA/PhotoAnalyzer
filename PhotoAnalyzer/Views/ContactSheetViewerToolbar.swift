//
//  ContactSheetViewerToolbar.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import SwiftUI

/// Toolbar controls for contact sheet page navigation and zoom.
struct ContactSheetViewerToolbar: View {
    let pageCount: Int
    let currentPageIndex: Int
    @Binding var zoom: Double
    let minimumZoom: Double
    let maximumZoom: Double
    let zoomSliderWidth: CGFloat
    let showPreviousPage: () -> Void
    let showNextPage: () -> Void
    let zoomOut: () -> Void
    let zoomIn: () -> Void
    let fitWidth: () -> Void
    let fitWindow: () -> Void
    let actualSize: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Contact Sheet")
                .font(.headline)

            if pageCount > 1 {
                Text("Page \(currentPageIndex + 1) of \(pageCount)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if pageCount > 1 {
                Button {
                    showPreviousPage()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentPageIndex <= 0)
                .help("Previous Page")
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button {
                    showNextPage()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentPageIndex >= pageCount - 1)
                .help("Next Page")
                .keyboardShortcut(.rightArrow, modifiers: [])

                Divider()
                    .frame(height: 18)
            }

            Button {
                zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom Out")
            .keyboardShortcut("-", modifiers: .command)

            Slider(value: $zoom, in: minimumZoom...maximumZoom)
                .frame(width: zoomSliderWidth)
                .help("Adjust Zoom")

            Button {
                zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom In")
            .keyboardShortcut("+", modifiers: .command)

            Button {
                fitWidth()
            } label: {
                Image(systemName: "arrow.left.and.right")
            }
            .help("Fit Width")
            .keyboardShortcut("0", modifiers: .command)

            Button {
                fitWindow()
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .help("Fit to Window")

            Button {
                actualSize()
            } label: {
                Text("100%")
                    .monospacedDigit()
            }
            .help("Actual Size")

            Button("Done") {
                close()
            }
            .keyboardShortcut(.defaultAction)
            .help("Close Contact Sheet Viewer")
        }
    }
}
