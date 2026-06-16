//
//  ColorExtractor.swift
//  music-player
//

import CoreGraphics
import ImageIO
import SwiftUI

/// Извлечение палитры из обложки для амбиентного фона. **Только чтение** данных
/// картинки. Берёт средний цвет уменьшенной обложки и строит из него пару оттенков.
nonisolated enum ColorExtractor {
    /// Усреднённый цвет обложки в линейных компонентах 0…1.
    private struct RGB {
        let red, green, blue: Double
    }

    /// Два цвета для амбиентных пятен фона или `nil`, если картинку не разобрать.
    static func ambientColors(from data: Data) -> [Color]? {
        guard let average = averageColor(from: data) else { return nil }
        let bright = Color(
            red: min(average.red * 1.15, 1),
            green: min(average.green * 1.15, 1),
            blue: min(average.blue * 1.15, 1)
        )
        let deep = Color(
            red: average.red * 0.55,
            green: average.green * 0.55,
            blue: average.blue * 0.55
        )
        return [bright, deep]
    }

    private static func averageColor(from data: Data) -> RGB? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 16
              ] as CFDictionary)
        else {
            return nil
        }

        // Сжимаем обложку в 1×1 — цвет этого пикселя и есть средний.
        var pixel: [UInt8] = [0, 0, 0, 0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(thumbnail, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        return RGB(
            red: Double(pixel[0]) / 255,
            green: Double(pixel[1]) / 255,
            blue: Double(pixel[2]) / 255
        )
    }
}
