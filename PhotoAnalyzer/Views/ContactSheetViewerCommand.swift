//
//  ContactSheetViewerCommand.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 18/06/2026.
//

import Foundation

/// Command sent from the SwiftUI toolbar to the AppKit scroll view.
struct ContactSheetViewerCommand: Equatable {
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
