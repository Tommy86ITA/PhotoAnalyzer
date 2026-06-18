//
//  FolderSelectionPanel.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import AppKit
import Foundation

/// Configures and presents folder selection panels used by the main window.
enum FolderSelectionPanel {
    static func selectFolder(canCreateDirectories: Bool = false, prompt: String? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = canCreateDirectories

        if let prompt {
            panel.prompt = prompt
        }

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }
}
