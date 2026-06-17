//
//  ContactSheetPreviewView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import AppKit
import SwiftUI

/// Preview of the generated `contact_sheet.jpg` file.
struct ContactSheetPreviewView: View {
    let image: NSImage?
    let packageStatus: PackageStatus
    let openViewer: () -> Void

    var body: some View {
        GroupBox("Contact Sheet Preview") {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: placeholderIcon)
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary)

                        Text(placeholderText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(minHeight: 240)
            .frame(maxHeight: .infinity)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                guard image != nil else {
                    return
                }

                openViewer()
            }
            .help(image == nil ? "" : "Open Contact Sheet")
        }
    }

    private var placeholderIcon: String {
        switch packageStatus {
        case .generating:
            return "clock"
        case .failed:
            return "exclamationmark.triangle"
        default:
            return "photo.on.rectangle.angled"
        }
    }

    private var placeholderText: String {
        switch packageStatus {
        case .generating:
            return "Generating preview..."
        case .failed:
            return "Preview unavailable"
        default:
            return "No contact sheet generated"
        }
    }
}
