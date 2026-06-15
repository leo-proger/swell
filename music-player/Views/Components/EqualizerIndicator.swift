//
//  EqualizerIndicator.swift
//  music-player
//

import SwiftUI

/// Анимированный эквалайзер из нескольких столбиков — маркер активного трека.
/// Когда `isAnimating` выключен, столбики замирают (пауза).
struct EqualizerIndicator: View {
    var isAnimating: Bool

    private let bars = 4
    @State private var animate = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0 ..< bars, id: \.self) { index in
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 2.5, height: barHeight(index))
                    .animation(
                        isAnimating
                            ? .easeInOut(duration: 0.42 + Double(index) * 0.08)
                            .repeatForever(autoreverses: true)
                            : .default,
                        value: animate
                    )
            }
        }
        .frame(width: 18, height: 16, alignment: .bottom)
        .onAppear { animate = isAnimating }
        .onChange(of: isAnimating) { _, newValue in animate = newValue }
    }

    private func barHeight(_ index: Int) -> CGFloat {
        let low: CGFloat = 4
        let high: [CGFloat] = [14, 9, 16, 11]
        return animate ? high[index % high.count] : low
    }
}
