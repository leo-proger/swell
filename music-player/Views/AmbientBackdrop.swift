//
//  AmbientBackdrop.swift
//  music-player
//

import SwiftUI

/// Амбиентное свечение от цвета текущего трека: два больших размытых пятна,
/// которые медленно дрейфуют. Лежит поверх блюра рабочего стола и придаёт
/// интерфейсу «живой», современный вид. При смене трека цвета плавно меняются.
struct AmbientBackdrop: View {
    let colors: [Color]

    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                blob(colors.first ?? .accentColor)
                    .frame(width: geo.size.width * 0.8)
                    .offset(
                        x: drift ? -geo.size.width * 0.22 : -geo.size.width * 0.3,
                        y: drift ? -geo.size.height * 0.28 : -geo.size.height * 0.12
                    )

                blob(colors.last ?? .accentColor)
                    .frame(width: geo.size.width * 0.9)
                    .offset(
                        x: drift ? geo.size.width * 0.28 : geo.size.width * 0.18,
                        y: drift ? geo.size.height * 0.24 : geo.size.height * 0.32
                    )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .blur(radius: 110)
        .opacity(0.55)
        .animation(.easeInOut(duration: 16).repeatForever(autoreverses: true), value: drift)
        .animation(.easeInOut(duration: 0.8), value: colors)
        .onAppear { drift = true }
        .allowsHitTesting(false)
    }

    private func blob(_ color: Color) -> some View {
        Circle().fill(color)
    }
}
