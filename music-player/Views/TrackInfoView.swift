//
//  TrackInfoView.swift
//  music-player
//

import SwiftUI

/// Лист с информацией о треке (только чтение метаданных).
struct TrackInfoView: View {
    let track: Track

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text(track.title)
                .font(.system(.title2, weight: .bold))
                .lineLimit(2)

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                row("Artist", track.artist)
                row("Album", track.album.isEmpty ? "—" : track.album)
                row("Duration", track.duration.timecode)
                row("File", track.fileName)
            }

            Text(track.url.path(percentEncoded: false))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(3)
                .textSelection(.enabled)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 420)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(.body, weight: .medium))
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}
