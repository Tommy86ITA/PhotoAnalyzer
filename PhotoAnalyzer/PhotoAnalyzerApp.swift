//
//  PhotoAnalyzerApp.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 15/06/2026.
//

import SwiftUI

@main
struct PhotoAnalyzerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: .openPhotoAnalyzerSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let openPhotoAnalyzerSettings = Notification.Name("openPhotoAnalyzerSettings")
}
