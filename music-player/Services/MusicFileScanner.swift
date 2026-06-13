//
//  MusicFileScanner.swift
//  music-player
//

import Foundation

/// Рекурсивный поиск аудиофайлов в папке. **Только чтение**: обходит дерево
/// каталога и не трогает ни один файл.
nonisolated enum MusicFileScanner {
    /// Поддерживаемые расширения аудио.
    static let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "flac", "wav", "aif", "aiff", "alac", "caf"
    ]

    /// Возвращает отсортированный по имени список аудиофайлов в папке.
    static func audioFiles(in folder: URL) -> [URL] {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var result: [URL] = []
        for case let url as URL in enumerator {
            guard audioExtensions.contains(url.pathExtension.lowercased()) else { continue }
            result.append(url)
        }

        return result.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }
}
