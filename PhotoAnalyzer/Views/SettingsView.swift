//
//  SettingsView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 20/06/2026.
//

import SwiftUI

/// Dedicated settings surface for persisted analysis preferences.
struct SettingsView: View {
    @Binding var includeSubfolders: Bool
    @Binding var useCurrentPhotosEncoding: Bool
    let canEditSettings: Bool
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Settings")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button("Done", action: dismiss)
                    .keyboardShortcut(.defaultAction)
            }

            Divider()

            Form {
                Section("Folder Analysis") {
                    Toggle("Include folder subfolders", isOn: $includeSubfolders)
                }

                Section("Photos Library") {
                    Toggle("Use current Photos encoding", isOn: $useCurrentPhotosEncoding)
                }
            }
            .formStyle(.grouped)
            .disabled(!canEditSettings)
        }
        .padding(24)
        .frame(width: 460, height: 260, alignment: .topLeading)
    }
}
