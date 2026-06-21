//
//  QueueRow.swift
//  music-player
//

import AppKit
import SwiftUI

/// Строка очереди: история (затемнена) или предстоящий трек (с маркером перетаскивания).
/// Лениво подгружает миниатюру обложки с дебаунсом — быстрый скролл не грузит лишнего.
struct QueueRow: View {
    enum Style { case history, upNext }

    let track: Track
    let style: Style

    @Environment(ArtworkProvider.self) private var artworkProvider
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            artwork

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if style == .upNext {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .onHover { inside in
                        if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
                    }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .opacity(style == .history ? 0.5 : 1)
        .task(id: track.id) {
            try? await Task.sleep(for: .milliseconds(120))
            if Task.isCancelled { return }
            thumbnail = await artworkProvider.thumbnail(for: track.url)
        }
    }

    private var artwork: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return shape
            .fill(track.artworkGradient)
            .frame(width: 40, height: 40)
            .overlay {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(shape)
                }
            }
            .overlay(shape.strokeBorder(.white.opacity(0.1), lineWidth: 1))
    }
}

/// Строка текущего трека в очереди: обложка, название/исполнитель + эквалайзер-индикатор.
struct QueueNowPlayingRow: View {
    let track: Track
    let cover: NSImage?

    @Environment(PlayerEngine.self) private var engine

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            artwork

            VStack(alignment: .leading, spacing: 3) {
                Text("NOW PLAYING")
                    .font(.system(.caption2, weight: .heavy))
                    .foregroundStyle(Theme.accent)
                    .tracking(0.8)
                Text(track.title)
                    .font(.system(.title3, weight: .bold))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            EqualizerIndicator(isAnimating: engine.isPlaying)
                .foregroundStyle(Theme.accent)
        }
        .padding(.vertical, Theme.Spacing.s)
    }

    private var artwork: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return shape
            .fill(track.artworkGradient)
            .frame(width: 60, height: 60)
            .overlay {
                if let cover {
                    Image(nsImage: cover)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(shape)
                }
            }
            .overlay(shape.strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1))
    }
}
