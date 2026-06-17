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
        static let toolbarSpacing: CGFloat = 12
        static let toolbarPadding: CGFloat = 16
        static let zoomSliderWidth: CGFloat = 180
        static let imagePadding: CGFloat = 24
        static let minimumVisibleImageLength: CGFloat = 80
    }

    private enum Zoom {
        static let minimum = 0.25
        static let maximum = 2.0
        static let step = 0.1
    }

    let image: NSImage
    let close: () -> Void

    @State private var zoom = 1.0
    @State private var gestureStartZoom: Double?
    @State private var gestureStartOffset = CGSize.zero
    @State private var imageOffset = CGSize.zero
    @State private var dragStartOffset: CGSize?
    @State private var viewportSize = CGSize.zero

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            GeometryReader { proxy in
                ZStack {
                    Color(nsColor: .windowBackgroundColor)

                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: max(1, image.size.width * zoom),
                            height: max(1, image.size.height * zoom)
                        )
                        .offset(imageOffset)
                }
                .clipped()
                .contentShape(Rectangle())
                .gesture(dragGesture)
                .simultaneousGesture(magnifyGesture)
                .onTapGesture(count: 2) {
                    fitToWindow()
                }
                .onAppear {
                    viewportSize = proxy.size
                    fitToWindow()
                }
                .onChange(of: proxy.size) { _, newSize in
                    viewportSize = newSize
                    imageOffset = clampedOffset(imageOffset)
                }
            }
        }
        .frame(minWidth: Layout.minimumWidth, minHeight: Layout.minimumHeight)
    }

    private var toolbar: some View {
        HStack(spacing: Layout.toolbarSpacing) {
            Text("Contact Sheet")
                .font(.headline)

            Spacer(minLength: 0)

            Button {
                zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom Out")
            .keyboardShortcut("-", modifiers: .command)

            Slider(
                value: Binding(
                    get: { zoom },
                    set: { setZoom($0, preservingViewportCenter: true) }
                ),
                in: Zoom.minimum...Zoom.maximum
            )
                .frame(width: Layout.zoomSliderWidth)

            Button {
                zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom In")
            .keyboardShortcut("+", modifiers: .command)

            Button {
                fitToWindow()
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .help("Fit to Window")
            .keyboardShortcut("0", modifiers: .command)

            Button("Done") {
                close()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(Layout.toolbarPadding)
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if gestureStartZoom == nil {
                    gestureStartZoom = zoom
                    gestureStartOffset = imageOffset
                }

                let baseZoom = gestureStartZoom ?? zoom
                let nextZoom = clampedZoom(baseZoom * value.magnification)
                zoom = nextZoom

                if baseZoom > 0 {
                    let scale = nextZoom / baseZoom
                    imageOffset = clampedOffset(CGSize(
                        width: gestureStartOffset.width * scale,
                        height: gestureStartOffset.height * scale
                    ))
                }
            }
            .onEnded { _ in
                gestureStartZoom = nil
                imageOffset = clampedOffset(imageOffset)
                gestureStartOffset = imageOffset
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartOffset == nil {
                    dragStartOffset = imageOffset
                }

                let startOffset = dragStartOffset ?? imageOffset
                imageOffset = clampedOffset(CGSize(
                    width: startOffset.width + value.translation.width,
                    height: startOffset.height + value.translation.height
                ))
            }
            .onEnded { _ in
                imageOffset = clampedOffset(imageOffset)
                dragStartOffset = nil
            }
    }

    private func zoomIn() {
        setZoom(zoom + Zoom.step, preservingViewportCenter: true)
    }

    private func zoomOut() {
        setZoom(zoom - Zoom.step, preservingViewportCenter: true)
    }

    private func fitToWindow() {
        guard image.size.width > 0,
              image.size.height > 0,
              viewportSize.width > 0,
              viewportSize.height > 0 else {
            return
        }

        let availableWidth = max(1, viewportSize.width - Layout.imagePadding * 2)
        let availableHeight = max(1, viewportSize.height - Layout.imagePadding * 2)
        let scale = min(
            availableWidth / image.size.width,
            availableHeight / image.size.height
        )
        zoom = clampedZoom(scale)
        imageOffset = clampedOffset(.zero)
    }

    private func clampedZoom(_ value: Double) -> Double {
        min(Zoom.maximum, max(Zoom.minimum, value))
    }

    private func setZoom(_ value: Double, preservingViewportCenter: Bool) {
        let previousZoom = zoom
        let nextZoom = clampedZoom(value)
        zoom = nextZoom

        guard preservingViewportCenter, previousZoom > 0 else {
            return
        }

        let scale = nextZoom / previousZoom
        imageOffset = clampedOffset(CGSize(
            width: imageOffset.width * scale,
            height: imageOffset.height * scale
        ))
    }

    private func clampedOffset(_ offset: CGSize) -> CGSize {
        clampOffset(
            offset,
            imageSize: image.size,
            viewportSize: viewportSize,
            zoom: zoom
        )
    }

    private func clampOffset(
        _ offset: CGSize,
        imageSize: CGSize,
        viewportSize: CGSize,
        zoom: CGFloat
    ) -> CGSize {
        guard imageSize.width > 0,
              imageSize.height > 0,
              viewportSize.width > 0,
              viewportSize.height > 0 else {
            return .zero
        }

        let scaledImageSize = CGSize(
            width: imageSize.width * zoom,
            height: imageSize.height * zoom
        )

        return CGSize(
            width: clampedAxisOffset(
                offset.width,
                contentLength: scaledImageSize.width,
                viewportLength: viewportSize.width
            ),
            height: clampedAxisOffset(
                offset.height,
                contentLength: scaledImageSize.height,
                viewportLength: viewportSize.height
            )
        )
    }

    private func clampedAxisOffset(
        _ offset: CGFloat,
        contentLength: CGFloat,
        viewportLength: CGFloat
    ) -> CGFloat {
        guard contentLength > viewportLength else {
            return 0
        }

        let minimumVisibleLength = min(Layout.minimumVisibleImageLength, contentLength)
        let maximumOffset = (contentLength + viewportLength) / 2 - minimumVisibleLength
        return min(maximumOffset, max(-maximumOffset, offset))
    }
}
