//
//  WindowPlacementView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import AppKit
import SwiftUI

/// Applies an initial macOS window size and centered placement.
struct WindowPlacementView: NSViewRepresentable {
    let size: CGSize
    let minimumSize: CGSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window, !context.coordinator.didPlaceWindow else {
                return
            }

            context.coordinator.didPlaceWindow = true
            window.minSize = minimumSize
            window.setContentSize(size)
            window.center()
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var didPlaceWindow = false
    }
}
