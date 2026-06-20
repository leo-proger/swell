//
//  Persistence.swift
//  music-player
//

import Foundation

/// Папка приложения в песочнице для кэша и состояния. Запись сюда разрешена без
/// дополнительных прав — это контейнер приложения, не пользовательские файлы.
nonisolated enum AppStorage {
    static func supportDirectory() -> URL? {
        let manager = FileManager.default
        guard let base = try? manager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }
        let directory = base.appendingPathComponent("Swell", isDirectory: true)
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Стабильный (не зависящий от запуска) хэш строки для имён файлов кэша.
    static func stableHash(_ string: String) -> String {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = (hash &* 33) ^ UInt64(byte)
        }
        return String(hash, radix: 16)
    }
}

/// Кэш отсканированной медиатеки: чтобы при старте не пересканировать тысячи файлов.
nonisolated enum LibraryCache {
    static func load(folderPath: String) -> [Track]? {
        guard let url = cacheURL(folderPath: folderPath),
              let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        return try? JSONDecoder().decode([Track].self, from: data)
    }

    static func save(_ tracks: [Track], folderPath: String) {
        guard let url = cacheURL(folderPath: folderPath),
              let data = try? JSONEncoder().encode(tracks)
        else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    private static func cacheURL(folderPath: String) -> URL? {
        AppStorage.supportDirectory()?
            .appendingPathComponent("library-\(AppStorage.stableHash(folderPath)).json")
    }
}

/// Сохранённое состояние воспроизведения для восстановления между запусками.
///
/// Очередь хранится по трём регионам модели (`PlayQueue`): история, ручная очередь и
/// контекстный хвост — чтобы после рестарта ручные треки и их приоритет были на месте.
/// URL'ы при восстановлении сверяются с актуальной медиатекой (пропавшие отбрасываются).
nonisolated struct PlaybackState: Codable {
    var history: [URL]
    var userQueue: [URL]
    var sourceQueue: [URL]
    var current: URL?
    var progress: TimeInterval
    var isShuffle: Bool
    var repeatMode: String
    var volume: Double
}

/// Персист состояния воспроизведения. Пишется часто (раз в секунду и на событиях),
/// поэтому переживает краши и резкие выходы.
nonisolated enum PlaybackPersistence {
    static func load() -> PlaybackState? {
        guard let url = fileURL(), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PlaybackState.self, from: data)
    }

    static func save(_ state: PlaybackState) {
        guard let url = fileURL(), let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func fileURL() -> URL? {
        AppStorage.supportDirectory()?.appendingPathComponent("playback.json")
    }
}
