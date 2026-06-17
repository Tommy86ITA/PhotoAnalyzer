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
    }

    private enum Zoom {
        static let minimum = 0.05
        static let maximum = 3.0
        static let step = 0.1
    }

    let image: NSImage
    let close: () -> Void

    @State private var zoom = 1.0
    @State private var pendingCommand: ContactSheetViewerCommand?

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            ContactSheetScrollImageView(
                image: image,
                zoom: $zoom,
                pendingCommand: $pendingCommand,
                minimumZoom: Zoom.minimum,
                maximumZoom: Zoom.maximum
            )
        }
        .frame(minWidth: Layout.minimumWidth, minHeight: Layout.minimumHeight)
        .onAppear {
            sendCommand(.fitWidth)
        }
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
                    set: { zoom = clampedZoom($0) }
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
                sendCommand(.fitWidth)
            } label: {
                Image(systemName: "arrow.left.and.right")
            }
            .help("Fit Width")
            .keyboardShortcut("0", modifiers: .command)

            Button {
                sendCommand(.fitWindow)
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .help("Fit to Window")

            Button {
                sendCommand(.actualSize)
            } label: {
                Text("100%")
                    .monospacedDigit()
            }
            .help("Actual Size")

            Button("Done") {
                close()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(Layout.toolbarPadding)
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

/// Command sent from the SwiftUI toolbar to the AppKit scroll view.
private struct ContactSheetViewerCommand: Equatable {
    enum Action {
        case fitWidth
        case fitWindow
        case actualSize
        case pageDown
        case pageUp
        case scrollToTop
        case scrollToBottom
    }

    let id = UUID()
    let action: Action
}

/// AppKit-backed image viewer with native scroll behavior and controlled zoom.
private struct ContactSheetScrollImageView: NSViewRepresentable {
    let image: NSImage
    @Binding var zoom: Double
    @Binding var pendingCommand: ContactSheetViewerCommand?
    let minimumZoom: Double
    let maximumZoom: Double

    func makeNSView(context: Context) -> ContactSheetScrollView {
        let scrollView = ContactSheetScrollView()
        let imageView = ContactSheetImageDocumentView(image: image)

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .windowBackgroundColor
        scrollView.allowsMagnification = false
        scrollView.documentView = imageView
        scrollView.coordinator = context.coordinator

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView
        context.coordinator.minimumZoom = CGFloat(minimumZoom)
        context.coordinator.maximumZoom = CGFloat(maximumZoom)
        context.coordinator.updateImage(image)
        context.coordinator.setZoom(CGFloat(zoom), preservingVisibleCenter: false)

        imageView.doubleClickAction = {
            context.coordinator.fitWidth()
        }

        DispatchQueue.main.async {
            scrollView.window?.makeFirstResponder(scrollView)
            context.coordinator.fitWidth()
        }

        return scrollView
    }

    func updateNSView(_ scrollView: ContactSheetScrollView, context: Context) {
        context.coordinator.minimumZoom = CGFloat(minimumZoom)
        context.coordinator.maximumZoom = CGFloat(maximumZoom)
        context.coordinator.zoomBinding = $zoom
        context.coordinator.updateImage(image)

        let nextZoom = context.coordinator.clampedZoom(CGFloat(zoom))
        if abs(nextZoom - context.coordinator.currentZoom) > 0.0001 {
            context.coordinator.setZoom(nextZoom, preservingVisibleCenter: true)
        }

        if let pendingCommand {
            context.coordinator.perform(pendingCommand.action)
            DispatchQueue.main.async {
                self.pendingCommand = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(zoom: $zoom)
    }

    final class Coordinator {
        var zoomBinding: Binding<Double>
        weak var scrollView: ContactSheetScrollView?
        weak var imageView: ContactSheetImageDocumentView?
        var minimumZoom: CGFloat = 0.05
        var maximumZoom: CGFloat = 3.0
        var currentZoom: CGFloat = 1.0

        init(zoom: Binding<Double>) {
            zoomBinding = zoom
        }

        func updateImage(_ image: NSImage) {
            guard imageView?.image !== image else {
                return
            }

            imageView?.image = image
            updateDocumentSize()
        }

        func perform(_ action: ContactSheetViewerCommand.Action) {
            switch action {
            case .fitWidth:
                fitWidth()
            case .fitWindow:
                fitWindow()
            case .actualSize:
                setZoom(1.0, preservingVisibleCenter: true)
            case .pageDown:
                scrollByVisiblePage(direction: 1)
            case .pageUp:
                scrollByVisiblePage(direction: -1)
            case .scrollToTop:
                scrollToTop()
            case .scrollToBottom:
                scrollToBottom()
            }
        }

        func magnify(with event: NSEvent) {
            let nextZoom = clampedZoom(currentZoom * (1 + event.magnification))
            setZoom(nextZoom, preservingVisibleCenter: true)
        }

        func keyDown(with event: NSEvent) -> Bool {
            switch event.keyCode {
            case 49 where event.modifierFlags.contains(.shift):
                scrollByVisiblePage(direction: -1)
                return true
            case 49:
                scrollByVisiblePage(direction: 1)
                return true
            case 116:
                scrollByVisiblePage(direction: -1)
                return true
            case 121:
                scrollByVisiblePage(direction: 1)
                return true
            case 115:
                scrollToTop()
                return true
            case 119:
                scrollToBottom()
                return true
            default:
                return false
            }
        }

        func fitWidth() {
            guard let scrollView, let imageView, imageView.image.size.width > 0 else {
                return
            }

            let viewportWidth = max(1, scrollView.contentView.bounds.width)
            let scale = viewportWidth / imageView.image.size.width
            setZoom(scale, preservingVisibleCenter: false)
            scrollToTop()
        }

        func fitWindow() {
            guard let scrollView, let imageView,
                  imageView.image.size.width > 0,
                  imageView.image.size.height > 0 else {
                return
            }

            let viewportSize = scrollView.contentView.bounds.size
            let scale = min(
                max(1, viewportSize.width) / imageView.image.size.width,
                max(1, viewportSize.height) / imageView.image.size.height
            )
            setZoom(scale, preservingVisibleCenter: false)
            scrollToTop()
        }

        func setZoom(_ zoom: CGFloat, preservingVisibleCenter: Bool) {
            guard let scrollView else {
                return
            }

            let previousCenter = preservingVisibleCenter ? visibleCenterInImageCoordinates() : nil
            currentZoom = clampedZoom(zoom)
            updateZoomBindingIfNeeded()
            updateDocumentSize()

            if let previousCenter {
                scroll(toImagePoint: previousCenter)
            } else {
                centerDocumentIfNeeded()
            }

            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        func clampedZoom(_ zoom: CGFloat) -> CGFloat {
            min(maximumZoom, max(minimumZoom, zoom))
        }

        private func updateDocumentSize() {
            guard let imageView else {
                return
            }

            let scaledSize = CGSize(
                width: max(1, imageView.image.size.width * currentZoom),
                height: max(1, imageView.image.size.height * currentZoom)
            )
            imageView.setFrameSize(scaledSize)
            imageView.needsDisplay = true
            centerDocumentIfNeeded()
        }

        private func updateZoomBindingIfNeeded() {
            let nextZoom = Double(currentZoom)

            guard abs(zoomBinding.wrappedValue - nextZoom) > 0.0001 else {
                return
            }

            DispatchQueue.main.async {
                self.zoomBinding.wrappedValue = nextZoom
            }
        }

        private func visibleCenterInImageCoordinates() -> CGPoint? {
            guard let scrollView else {
                return nil
            }

            let visibleRect = scrollView.contentView.bounds
            return CGPoint(
                x: visibleRect.midX / max(currentZoom, 0.0001),
                y: visibleRect.midY / max(currentZoom, 0.0001)
            )
        }

        private func scroll(toImagePoint imagePoint: CGPoint) {
            guard let scrollView, let imageView else {
                return
            }

            let viewportSize = scrollView.contentView.bounds.size
            let targetOrigin = CGPoint(
                x: imagePoint.x * currentZoom - viewportSize.width / 2,
                y: imagePoint.y * currentZoom - viewportSize.height / 2
            )
            let clampedOrigin = clampedScrollOrigin(targetOrigin, documentSize: imageView.bounds.size, viewportSize: viewportSize)
            scrollView.contentView.scroll(to: clampedOrigin)
            centerDocumentIfNeeded()
        }

        private func scrollByVisiblePage(direction: CGFloat) {
            guard let scrollView, let imageView else {
                return
            }

            let visibleRect = scrollView.contentView.bounds
            let pageDelta = visibleRect.height * 0.9 * direction
            let targetOrigin = CGPoint(x: visibleRect.origin.x, y: visibleRect.origin.y + pageDelta)
            let clampedOrigin = clampedScrollOrigin(
                targetOrigin,
                documentSize: imageView.bounds.size,
                viewportSize: visibleRect.size
            )
            scrollView.contentView.scroll(to: clampedOrigin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        private func scrollToTop() {
            guard let scrollView else {
                return
            }

            let visibleRect = scrollView.contentView.bounds
            scrollView.contentView.scroll(to: CGPoint(x: visibleRect.origin.x, y: 0))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            centerDocumentIfNeeded()
        }

        private func scrollToBottom() {
            guard let scrollView, let imageView else {
                return
            }

            let visibleRect = scrollView.contentView.bounds
            let maxY = max(0, imageView.bounds.height - visibleRect.height)
            scrollView.contentView.scroll(to: CGPoint(x: visibleRect.origin.x, y: maxY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            centerDocumentIfNeeded()
        }

        private func centerDocumentIfNeeded() {
            guard let scrollView, let imageView else {
                return
            }

            let viewportSize = scrollView.contentView.bounds.size
            let horizontalInset = max(0, (viewportSize.width - imageView.bounds.width) / 2)
            let verticalInset = max(0, (viewportSize.height - imageView.bounds.height) / 2)
            scrollView.contentInsets = NSEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }

        private func clampedScrollOrigin(
            _ origin: CGPoint,
            documentSize: CGSize,
            viewportSize: CGSize
        ) -> CGPoint {
            CGPoint(
                x: min(max(0, documentSize.width - viewportSize.width), max(0, origin.x)),
                y: min(max(0, documentSize.height - viewportSize.height), max(0, origin.y))
            )
        }
    }
}

/// Scroll view that forwards trackpad magnification and page navigation to its coordinator.
private final class ContactSheetScrollView: NSScrollView {
    weak var coordinator: ContactSheetScrollImageView.Coordinator?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func magnify(with event: NSEvent) {
        coordinator?.magnify(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if coordinator?.keyDown(with: event) == true {
            return
        }

        super.keyDown(with: event)
    }
}

/// Lightweight document view that draws the contact sheet at the current zoom size.
private final class ContactSheetImageDocumentView: NSView {
    var image: NSImage {
        didSet {
            needsDisplay = true
        }
    }

    var doubleClickAction: (() -> Void)?

    override var isFlipped: Bool {
        true
    }

    init(image: NSImage) {
        self.image = image
        super.init(frame: NSRect(origin: .zero, size: image.size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
        image.draw(
            in: bounds,
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            doubleClickAction?()
            return
        }

        super.mouseDown(with: event)
    }
}
