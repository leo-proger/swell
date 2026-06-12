//
//  Formatting.swift
//  music-player
//

import SwiftUI

extension TimeInterval {
    /// Таймкод вида `m:ss` для моноширинного отображения.
    var timecode: String {
        guard isFinite, self >= 0 else { return "0:00" }
        let total = Int(rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

extension View {
    /// Единое оформление таймкодов: SF Mono + неразъезжающиеся цифры.
    /// Моноширинные цифры — фирменная деталь: при перемотке счётчик не дёргается.
    func monoTimecode() -> some View {
        font(.system(.caption, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }
}
