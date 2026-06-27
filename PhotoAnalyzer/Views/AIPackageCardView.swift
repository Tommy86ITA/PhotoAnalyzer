//
//  AIPackageCardView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import SwiftUI

/// AI package status and generated file checklist.
struct AIPackageCardView: View {
    let packageState: AIPackageUIState
    let isAnalyzing: Bool
    let openPackage: () -> Void
    let revealArchive: () -> Void

    private var canOpenPackage: Bool {
        guard let packageURL = packageState.packageURL else {
            return false
        }

        return FileManager.default.fileExists(atPath: packageURL.path)
    }

    var body: some View {
        GroupBox("AI Package") {
            VStack(alignment: .leading, spacing: 14) {
                DashboardMetricRow(
                    title: "Status",
                    value: packageState.status.displayText,
                    systemImage: statusIcon,
                    helpText: "Current generation status for the AI analysis package."
                )
                PackagePathRow(
                    packageURL: packageState.packageURL,
                    packagePathText: packageState.packagePathText
                )

                VStack(spacing: 8) {
                    PackageFileRow(fileName: AIAnalysisPackagePaths.metadataFileName, exists: packageState.metadataExists)
                    PackageFileRow(fileName: AIAnalysisPackagePaths.statisticsFileName, exists: packageState.statisticsExists)
                    PackageFileRow(fileName: AIAnalysisPackagePaths.contactSheetFileName, exists: packageState.contactSheetExists)
                    PackageFileRow(fileName: AIAnalysisPackagePaths.indexFileName, exists: packageState.indexExists)
                    PackageFileRow(fileName: archiveFileName, exists: packageState.archiveExists)
                }
                .padding(.top, 2)

                if let error = packageState.error {
                    Text(error.userMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .textSelection(.enabled)
                        .help(error.debugDescription)
                }

                HStack(spacing: 10) {
                    Button(action: openPackage) {
                        Label("Open Package", systemImage: "folder")
                    }
                    .disabled(!canOpenPackage || isAnalyzing)
                    .help(canOpenPackage ? "Open Generated Package Folder" : "Generate a package before opening it")

                    Button(action: revealArchive) {
                        Label("Reveal Archive", systemImage: "doc.zipper")
                    }
                    .disabled(!packageState.archiveExists || isAnalyzing)
                    .help(packageState.archiveExists ? "Reveal Package Archive in Finder" : "Generate an archive before revealing it")

                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var statusIcon: String {
        switch packageState.status {
        case .notGenerated:
            return "circle"
        case .generating:
            return "clock"
        case .generated:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    private var archiveFileName: String {
        guard let packageURL = packageState.packageURL else {
            return "package.zip"
        }

        return "\(packageURL.lastPathComponent).zip"
    }
}

private struct PackagePathRow: View {
    let packageURL: URL?
    let packagePathText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text("Package Path")
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(packagePathText)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(packageURL?.path ?? packagePathText)

            CopyPathButton(path: packageURL?.path)
        }
        .help(packageURL?.path ?? packagePathText)
    }
}

private struct PackageFileRow: View {
    let fileName: String
    let exists: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: exists ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(exists ? .green : .secondary)
                .frame(width: 18)

            Text(fileName)
                .font(.system(.body, design: .monospaced))

            Spacer(minLength: 0)

            Text(exists ? "Ready" : "--")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .help(exists ? "\(fileName) was generated successfully." : "\(fileName) has not been generated yet.")
    }
}
