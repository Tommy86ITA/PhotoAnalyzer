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
    let progress: AnalysisProgress?

    private var shouldShowProgress: Bool {
        isBusy || progress != nil
    }

    private var displayedProgress: AnalysisProgress? {
        progress
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                } else if shouldShowProgress {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }

                Text(displayedProgress?.message ?? statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                if let displayedProgress {
                    Text(displayedProgress.fractionCompleted, format: .percent.precision(.fractionLength(0)))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 18, alignment: .center)

            LinearProgressBar(value: displayedProgress?.fractionCompleted ?? 0)
                .opacity(shouldShowProgress ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .frame(height: 44, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct LinearProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * min(1, max(0, value))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                Capsule()
                    .fill(.tint)
                    .frame(width: width)
            }
        }
        .frame(height: 4)
    }
}
