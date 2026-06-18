//
//  SecondaryControls.swift
//  music-player
//

import SwiftUI

/// Второстепенные режимы воспроизведения: перемешивание и повтор (off → all → one).
/// Активный режим подсвечивается акцентом.
struct SecondaryControls: View {
    @Environment(PlayerEngine.self) private var engine

    var body: some View {
        HStack(spacing: Theme.Spacing.xl) {
            button("shuffle", active: engine.isShuffle, help: "Shuffle") {
                engine.isShuffle.toggle()
            }
            button(repeatSymbol, active: engine.repeatMode != .off, help: "Repeat") {
                cycleRepeat()
            }
        }
    }

    private func button(
        _ symbol: String,
        active: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(active ? Theme.accent : .secondary)
                .frame(width: 40, height: 40)
                .contentTransition(.symbolEffect(.replace))
                .glassEffect(.regular.interactive(), in: .circle)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var repeatSymbol: String {
        engine.repeatMode == .one ? "repeat.1" : "repeat"
    }

    private func cycleRepeat() {
        switch engine.repeatMode {
        case .off: engine.repeatMode = .all
        case .all: engine.repeatMode = .one
        case .one: engine.repeatMode = .off
        }
    }
}
