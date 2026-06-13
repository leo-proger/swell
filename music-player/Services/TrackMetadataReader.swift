//
//  TrackMetadataReader.swift
//  music-player
//

import AVFoundation

/// Чтение тегов трека через AVFoundation. **Только чтение**: открывает файл лишь
/// для извлечения метаданных, никогда не пишет. Нечитаемый файл не роняет загрузку —
/// возвращается трек с именем файла вместо названия.
nonisolated enum TrackMetadataReader {
    static func read(url: URL) async -> Track {
        let asset = AVURLAsset(url: url)

        var title: String?
        var artist: String?
        var album: String?
        var duration: TimeInterval = 0

        if let seconds = try? await asset.load(.duration).seconds, seconds.isFinite {
            duration = seconds
        }

        if let items = try? await asset.load(.commonMetadata) {
            for item in items {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    title = try? await item.load(.stringValue)
                case .commonKeyArtist:
                    artist = try? await item.load(.stringValue)
                case .commonKeyAlbumName:
                    album = try? await item.load(.stringValue)
                default:
                    break
                }
            }
        }

        return Track(
            url: url,
            title: title?.nonEmpty ?? url.deletingPathExtension().lastPathComponent,
            artist: artist?.nonEmpty ?? "Unknown Artist",
            album: album?.nonEmpty ?? "",
            duration: duration
        )
    }
}

private extension String {
    /// Возвращает строку, если она не пустая после обрезки пробелов.
    nonisolated var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
