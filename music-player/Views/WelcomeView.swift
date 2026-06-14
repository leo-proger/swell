//
//  WelcomeView.swift
//  music-player
//

import SwiftUI

/// Стартовый экран, пока не выбрана папка с музыкой.
struct WelcomeView: View {
    @Environment(LibraryStore.self) private var library

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "water.waves")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.accent)

            VStack(spacing: Theme.Spacing.s) {
                Text("Swell")
                    .font(.system(size: 40, weight: .bold))
                Text("Choose a music folder to build your library.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await library.chooseFolder() }
            } label: {
                Label("Choose music folder", systemImage: "folder")
                    .font(.headline)
                    .padding(.horizontal, Theme.Spacing.s)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)

            Label(
                "Swell opens files read-only and never changes anything on disk.",
                systemImage: "lock.shield"
            )
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .padding(.top, Theme.Spacing.s)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
