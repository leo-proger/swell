//
//  ArtworkLoader.swift
//  music-player
//

import AVFoundation

/// Ленивая загрузка встроенной обложки трека. **Только чтение**. Возвращает сырые
/// байты картинки (Sendable) — сам `NSImage` собирается уже на главном потоке.
/// Грузим обложку лишь для текущего трека, поэтому 3к треков не висят в памяти.
nonisolated enum ArtworkLoader {
    static func load(url: URL) async -> Data? {
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.commonMetadata) else { return nil }

        for item in items where item.commonKey == .commonKeyArtwork {
            if let data = try? await item.load(.dataValue) {
                return data
            }
        }
        return nil
    }
}
