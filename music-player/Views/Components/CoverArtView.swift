//
//  CoverArtView.swift
//  music-player
//

import AppKit
import SwiftUI

/// Крупная обложка текущего трека в правой панели. Если обложки нет — градиент-заглушка.
/// Большой размер «дышит» на паузе (лёгкое уменьшение), подчёркивая остановку.
struct CoverArtView: View {
    let track: Track
    let cover: NSImage?
    var size: CGFloat = 280
    var cornerRadius: CGFloat = 22

    @Environment(PlayerEngine.self) private var engine

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isLarge = size > 100
        return shape
            .fill(track.artworkGradient)
            .frame(width: size, height: size)
            .overlay {
                if let cover {
                    Image(nsImage: cover)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(shape)
                }
            }
            .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .shadow(
                color: .black.opacity(isLarge ? 0.35 : 0.2),
                radius: isLarge ? 24 : 10,
                y: isLarge ? 12 : 5
            )
            .scaleEffect(isLarge && !engine.isPlaying ? 0.94 : 1)
            .animation(.spring(response: 0.45, dampingFraction: 0.72), value: engine.isPlaying)
    }
}
