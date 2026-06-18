//
//  VolumeSlider.swift
//  music-player
//

import SwiftUI

/// Регулятор громкости с иконками тихо/громко по краям. Пишет прямо в `engine.volume`.
struct VolumeSlider: View {
    @Environment(PlayerEngine.self) private var engine

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: Bindable(engine).volume, in: 0 ... 1)
            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
