//
//  Track.swift
//  music-player
//

import SwiftUI

/// Трек медиатеки. Источник истины — файл на диске; модель только описывает его,
/// никогда не владеет содержимым и не меняет файл.
///
/// `nonisolated` — модель должна свободно создаваться в фоне при сканировании.
/// `Codable` — чтобы кэшировать медиатеку и сохранять очередь между запусками.
nonisolated struct Track: Identifiable, Hashable, Codable {
    /// Идентификатор — путь к файлу: стабилен между запусками.
    var id: URL {
        url
    }

    let url: URL
    let title: String
    let artist: String
    let album: String
    /// Длительность трека в секундах.
    let duration: TimeInterval

    var fileName: String {
        url.lastPathComponent
    }
}

extension Track {
    /// Два цвета, выведенные из названия. Используются для обложки-заглушки и для
    /// амбиентного свечения фона, когда у трека нет встроенной обложки.
    var artworkColors: [Color] {
        let hue = Double(abs(title.hashValue) % 360) / 360
        let secondHue = (hue + 0.1).truncatingRemainder(dividingBy: 1)
        return [
            Color(hue: hue, saturation: 0.6, brightness: 0.72),
            Color(hue: secondHue, saturation: 0.7, brightness: 0.46)
        ]
    }

    /// Детерминированный градиент-заглушка вместо обложки.
    var artworkGradient: LinearGradient {
        LinearGradient(
            colors: artworkColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
