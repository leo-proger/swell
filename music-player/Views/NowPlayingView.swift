//
//  NowPlayingView.swift
//  music-player
//

import AppKit
import SwiftUI

/// Правая зона — «сейчас играет» поверх амбиентного свечения.
///
/// Два режима (полный плеер / очередь) переключаются только через opacity:
/// оба всегда в дереве → layout никогда не пересчитывается → нет сдвигов
/// и кнопка-тоггл всегда стоит на месте. Конкретные элементы управления вынесены
/// в компоненты (`TransportControls`, `VolumeSlider`, `SecondaryControls`, …).
struct NowPlayingView: View {
    let cover: NSImage?

    @Environment(PlayerEngine.self) private var engine
    @State private var showQueue = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let track = engine.currentTrack {
                    playerContent(for: track)
                } else {
                    ContentUnavailableView(
                        "Nothing playing",
                        systemImage: "music.note",
                        description: Text("Select a track from the library")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.l)

            if engine.currentTrack != nil {
                QueueToggleButton(showQueue: $showQueue)
                    .padding(Theme.Spacing.xl)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: engine.currentTrackID)
    }

    // MARK: - Оба режима всегда в дереве

    private func playerContent(for track: Track) -> some View {
        ZStack {
            fullPlayer(for: track)
                .opacity(showQueue ? 0 : 1)
                .allowsHitTesting(!showQueue)

            queueContent()
                .opacity(showQueue ? 1 : 0)
                .allowsHitTesting(showQueue)
        }
    }

    // MARK: - Обычный режим

    private func fullPlayer(for track: Track) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer(minLength: 0)

            CoverArtView(track: track, cover: cover)

            VStack(spacing: Theme.Spacing.xs) {
                Text(track.title)
                    .font(.system(.title, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(.title3, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(track.album)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            ScrubBar(
                progress: engine.progress,
                duration: track.duration,
                onSeek: { engine.seek(to: $0) }
            )
            .frame(maxWidth: 360)

            TransportControls(compact: false)

            VolumeSlider()
                .frame(maxWidth: 360)

            Spacer(minLength: 0)

            SecondaryControls()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Режим очереди

    /// Текущий трек — посередине между историей и очередью (как в Apple Music iOS).
    /// Транспорт зафиксирован снизу вне скроллируемого списка.
    private func queueContent() -> some View {
        VStack(spacing: 0) {
            QueueView(currentCover: cover, isActive: showQueue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(0.3)

            TransportControls(compact: true)
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.m)
                .padding(.horizontal, Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
