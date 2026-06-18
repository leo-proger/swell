//
//  TransportControls.swift
//  music-player
//

import SwiftUI

/// Основной транспорт: предыдущий / play-pause / следующий. Круглые Liquid Glass
/// кнопки; центральная (play) — акцентно-проминентная. Режим `compact` — для очереди.
struct TransportControls: View {
    let compact: Bool

    @Environment(PlayerEngine.self) private var engine

    var body: some View {
        GlassEffectContainer(spacing: compact ? Theme.Spacing.s : Theme.Spacing.m) {
            HStack(spacing: compact ? Theme.Spacing.s : Theme.Spacing.l) {
                circleButton("backward.fill", diameter: compact ? 32 : 50) { engine.previous() }
                circleButton(
                    engine.isPlaying ? "pause.fill" : "play.fill",
                    diameter: compact ? 44 : 68,
                    prominent: true
                ) {
                    engine.togglePlayPause()
                }
                circleButton("forward.fill", diameter: compact ? 32 : 50) { engine.next() }
            }
        }
    }

    private func circleButton(
        _ symbol: String,
        diameter: CGFloat,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: prominent ? diameter * 0.36 : diameter * 0.34, weight: .semibold))
                .foregroundStyle(prominent ? Theme.accent : .primary)
                .frame(width: diameter, height: diameter)
                .contentTransition(.symbolEffect(.replace))
                .glassEffect(
                    prominent
                        ? .regular.tint(Theme.accent.opacity(0.22)).interactive()
                        : .regular.interactive(),
                    in: .circle
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
