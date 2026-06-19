//
//  DashboardMetricRow.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import SwiftUI

/// A compact key-value row used in PhotoAnalyzer dashboard sections.
struct DashboardMetricRow: View {
    let title: String
    let value: String
    let systemImage: String
    var helpText: String?
    var isMonospaced = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .modifier(MonospacedIfNeeded(isEnabled: isMonospaced))
                .help(helpText ?? value)
        }
        .help(helpText ?? "\(title): \(value)")
    }
}

private struct MonospacedIfNeeded: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .font(.system(.body, design: .monospaced))
                .monospacedDigit()
        } else {
            content
                .monospacedDigit()
        }
    }
}
