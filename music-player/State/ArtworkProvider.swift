//
//  ArtworkProvider.swift
//  music-player
//

import AppKit
import ImageIO
import Observation

/// Поставщик миниатюр обложек для списка. Грузит только видимое и кэширует.
///
/// Производительность: вся тяжёлая работа (чтение тегов + декод и уменьшение
/// картинки через `CGImageSource`) идёт в фоне; на главном потоке остаётся лишь
/// дешёвая обёртка готового `CGImage` в `NSImage` — поэтому скролл не лагает.
@MainActor
@Observable
final class ArtworkProvider {
    @ObservationIgnored private let cache = NSCache<NSURL, NSImage>()

    init() {
        cache.countLimit = 600
    }

    /// Миниатюра обложки трека (или `nil`, если обложки нет).
    func thumbnail(for url: URL) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        guard let cgImage = await Self.makeThumbnail(url: url) else {
            return nil
        }
        let image = NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    /// Готовит миниатюру целиком в фоне: AVFoundation достаёт байты обложки,
    /// `CGImageSource` эффективно строит уменьшенную картинку без декода на main.
    private nonisolated static func makeThumbnail(url: URL) async -> CGImage? {
        guard let data = await ArtworkLoader.load(url: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil)
        else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 88,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
