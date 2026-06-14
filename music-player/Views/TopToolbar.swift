//
//  TopToolbar.swift
//  music-player
//

import SwiftUI

/// Верхняя зона — бренд, текущая папка и общее управление медиатекой: обновить,
/// сменить папку. Поиск — в шапке списка, транспорт — в правой панели.
struct TopToolbar: View {
    @Environment(LibraryStore.self) private var library

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Text("Swell")
                .font(.system(size: 18, weight: .bold))

            if let folderName = library.folderName {
                Label(folderName, systemImage: "folder")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
            }

            Spacer(minLength: Theme.Spacing.l)

            GlassActionButton(systemImage: "arrow.clockwise") {
                Task { await library.reload() }
            }
            .disabled(library.folderName == nil || library.isScanning)
            .help("Reload folder")

            GlassActionButton(systemImage: "folder") {
                Task { await library.chooseFolder() }
            }
            .help("Change folder")
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.m)
    }
}
