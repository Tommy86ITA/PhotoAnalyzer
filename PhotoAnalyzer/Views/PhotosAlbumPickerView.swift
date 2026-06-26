//
//  PhotosAlbumPickerView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 26/06/2026.
//

import SwiftUI

/// Sheet for choosing a PhotoKit album as the active Photos source.
struct PhotosAlbumPickerView: View {
    let albums: [PhotosAlbumSummary]
    let isLoading: Bool
    let error: AppErrorInfo?
    let selectAlbum: (PhotosAlbumSummary) -> Void
    let refresh: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Choose Album")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button("Done", action: dismiss)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }

            Divider()

            content
        }
        .padding(24)
        .frame(width: 520, height: 440, alignment: .topLeading)
        .onAppear(perform: refresh)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Loading albums...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error {
            VStack(alignment: .leading, spacing: 12) {
                Label(error.userMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)

                Button("Try Again", action: refresh)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if albums.isEmpty {
            ContentUnavailableView(
                "No Albums",
                systemImage: "photo.on.rectangle.angled",
                description: Text("No Photos albums with image assets were found.")
            )
        } else {
            List(albums) { album in
                Button {
                    selectAlbum(album)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.stack")
                            .foregroundStyle(.secondary)
                            .frame(width: 18)

                        Text(album.title)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(album.imageAssetCount.formatted())
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        }
    }
}
