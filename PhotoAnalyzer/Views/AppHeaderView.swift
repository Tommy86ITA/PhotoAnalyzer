//
//  AppHeaderView.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 16/06/2026.
//

import SwiftUI

/// Header for the PhotoAnalyzer package generation console.
struct AppHeaderView: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 38))
                .foregroundStyle(.tint)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 5) {
                Text("PhotoAnalyzer")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("Generate AI-ready photo analysis packages")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
