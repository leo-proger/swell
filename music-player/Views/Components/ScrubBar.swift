//
//  ScrubBar.swift
//  music-player
//

import SwiftUI

/// Полоса перемотки как точный инструмент: тонкая дорожка, акцентная заливка
/// пройденного и круглая игла. Таймкоды по краям — моноширинные.
struct ScrubBar: View {
    let progress: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void

    /// Доля, удерживаемая пальцем во время перетаскивания (перебивает `progress`).
    @State private var dragFraction: Double?

    var body: some View {
        let fraction = dragFraction ?? (duration > 0 ? progress / duration : 0)
        let shownTime = (dragFraction.map { $0 * duration }) ?? progress

        HStack(spacing: Theme.Spacing.s) {
            Text(shownTime.timecode).monoTimecode()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.18))
                        .frame(height: 3)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: max(0, geo.size.width * fraction), height: 3)
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 10, height: 10)
                        .offset(x: geo.size.width * fraction - 5)
                        .shadow(color: Theme.accent.opacity(0.5), radius: 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragFraction = clamp(value.location.x / geo.size.width)
                        }
                        .onEnded { value in
                            onSeek(clamp(value.location.x / geo.size.width) * duration)
                            dragFraction = nil
                        }
                )
            }
            .frame(height: 16)

            Text(duration.timecode).monoTimecode()
        }
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
