//
//  CopyPathButton.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 17/06/2026.
//

import AppKit
import SwiftUI

/// Small icon button for copying file system paths to the macOS pasteboard.
struct CopyPathButton: View {
    let path: String?

    @State private var didCopy = false

    private var canCopy: Bool {
        guard let path, !path.isEmpty else {
            return false
        }

        return true
    }

    var body: some View {
        Button(action: copyPath) {
            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.borderless)
        .disabled(!canCopy)
        .foregroundStyle(didCopy ? .green : .secondary)
        .help(didCopy ? "Copied" : "Copy Path")
    }

    private func copyPath() {
        guard let path, !path.isEmpty else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)

        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            didCopy = false
        }
    }
}
