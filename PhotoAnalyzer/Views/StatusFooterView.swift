//
//  StatusFooterView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import SwiftUI

/// Compact footer for current app status.
struct StatusFooterView: View {
    let statusMessage: String
    let isBusy: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }

            Text(statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
