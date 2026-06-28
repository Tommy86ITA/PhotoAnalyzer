//
//  ContactSheetViewerToolbar.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import SwiftUI

/// Toolbar controls for contact sheet page navigation and zoom.
struct ContactSheetViewerToolbar: View {
    private enum Layout {
        static let zoomSliderWidth: CGFloat = 210
    }

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
    let revealCurrentPage: () -> Void
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
                ControlGroup {
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
                }

                Divider()
                    .frame(height: 18)
            }

            ControlGroup {
                Button {
                    zoomOut()
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .help("Zoom Out")
                .keyboardShortcut("-", modifiers: .command)

                Button {
                    actualSize()
                } label: {
                    Text("1:1")
                        .monospacedDigit()
                }
                .help("Actual Size")

                Button {
                    zoomIn()
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .help("Zoom In")
                .keyboardShortcut("+", modifiers: .command)
            }

            Slider(value: $zoom, in: minimumZoom...maximumZoom)
                .frame(width: max(Layout.zoomSliderWidth, zoomSliderWidth))
                .help("Adjust Zoom")

            Text(zoomText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)

            ControlGroup {
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
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .help("Fit Page")

                Button {
                    revealCurrentPage()
                } label: {
                    Image(systemName: "folder")
                }
                .help("Reveal Current Contact Sheet Page in Finder")
            }

            Button("Done") {
                close()
            }
            .keyboardShortcut(.defaultAction)
            .help("Close Contact Sheet Viewer")
        }
    }

    private var zoomText: String {
        "\(Int((zoom * 100).rounded()))%"
    }
}
