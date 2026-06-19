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
    let currentPageIndex: Int
    let pageCount: Int
    let previousPage: () -> Void
    let nextPage: () -> Void
    let openViewer: () -> Void

    @State private var isHovering = false

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

                    if pageCount > 1 {
                        pageControls
                            .opacity(isHovering ? 1 : 0)
                            .allowsHitTesting(isHovering)
                    }
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
            .onHover { isHovering = $0 }
            .help(image == nil ? "" : "Open Contact Sheet")
        }
    }

    private var pageControls: some View {
        VStack {
            HStack {
                if currentPageIndex > 0 {
                    pageButton(
                        systemImage: "chevron.left",
                        helpText: "Previous Page",
                        action: previousPage
                    )
                }

                Spacer(minLength: 0)

                if currentPageIndex < pageCount - 1 {
                    pageButton(
                        systemImage: "chevron.right",
                        helpText: "Next Page",
                        action: nextPage
                    )
                }
            }

            Spacer(minLength: 0)

            Text("Page \(currentPageIndex + 1) of \(pageCount)")
                .font(.footnote.monospacedDigit())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
        }
        .padding(12)
    }

    private func pageButton(
        systemImage: String,
        helpText: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .background(.regularMaterial, in: Circle())
        .help(helpText)
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
