//
//  SampleData.swift
//  music-player
//

import Foundation

extension Track {
    /// Тестовые треки только для SwiftUI-превью (файлы не существуют, не играют).
    static let samples: [Track] = [
        sample("Nightfall Drift", "Aurora Veil", "Slow Horizons", 224),
        sample("Glass Corridor", "Möbius", "Refraction", 198),
        sample("Tahoe Blue", "Cold Signal", "Altitude", 271),
        sample("Paper Lanterns", "Hana Sato", "Quiet City", 183),
        sample("Undertow", "Aurora Veil", "Slow Horizons", 246)
    ]

    private static func sample(
        _ title: String,
        _ artist: String,
        _ album: String,
        _ duration: TimeInterval
    ) -> Track {
        Track(
            url: URL(fileURLWithPath: "/Preview/\(title).flac"),
            title: title,
            artist: artist,
            album: album,
            duration: duration
        )
    }
}
